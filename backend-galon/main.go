package main

import (
	"backend-galon/database"
	"backend-galon/handler"
	"backend-galon/service"
	"crypto/rand"
	"crypto/sha512"
	"database/sql"
	"encoding/hex"
	"fmt"
	"log"
	"net/http"
	"os"

	"github.com/joho/godotenv"

	"github.com/gin-gonic/gin"
)

type Product struct {
	ID         int    `json:"id"`
	CategoryID int    `json:"category_id"`
	Merk       string `json:"merk"`
	Price      int    `json:"price"`
	Stock      int    `json:"stock"`
	Image      string `json:"image"`
}

type OrderItem struct {
	ProductID int    `json:"product_id"`
	Qty       int    `json:"qty"`
	Subtotal  int    `json:"subtotal"`
	Service   string `json:"service"`
}

type Order struct {
	UserID          string `json:"user_id"`
	IdempotencyKey  string `json:"idempotency_key"`
	PaymentMethodID int    `json:"payment_method_id"`
	PaymentChannel  string `json:"payment_channel"`
	MidtransOrderID string `json:"midtrans_order_id"`

	Total int `json:"total"`

	VoucherCode     string `json:"voucher_code"`
	VoucherDiscount int    `json:"voucher_discount"`

	Status        string `json:"status"`
	PaymentStatus string `json:"payment_status"`

	Items []OrderItem `json:"items"`
}

type OrderResponse struct {
	ID        int    `json:"id"`
	Total     int    `json:"total"`
	Status    string `json:"status"`
	CreatedAt string `json:"created_at"`
}

type OrderDetailItem struct {
	Merk     string `json:"merk"`
	Qty      int    `json:"qty"`
	Subtotal int    `json:"subtotal"`
}

type OrderDetailResponse struct {
	ID     int               `json:"id"`
	Status string            `json:"status"`
	Total  int               `json:"total"`
	Items  []OrderDetailItem `json:"items"`
}

type User struct {
	FirebaseUID string `json:"firebase_uid"`
	Email       string `json:"email"`
	Name        string `json:"name"`
	Phone       string `json:"phone"`
	Address     string `json:"address"`
}

type Voucher struct {
	ID       int    `json:"id"`
	Code     string `json:"code"`
	Discount int    `json:"discount"`
	IsActive bool   `json:"is_active"`
}

type UserVoucher struct {
	ID        int    `json:"id"`
	UserID    string `json:"user_id"`
	Code      string `json:"code"`
	Discount  int    `json:"discount"`
	IsUsed    bool   `json:"is_used"`
	CreatedAt string `json:"created_at"`
}

func generateVoucherCode() string {
	buf := make([]byte, 3)
	_, err := rand.Read(buf)
	if err != nil {
		return fmt.Sprintf("VOUCHER-%d", os.Getpid())
	}
	return fmt.Sprintf("VOUCHER-%s", hex.EncodeToString(buf))
}

func main() {

	godotenv.Load()

	database.InitFirebase()

	database.ConnectDB()

	var columnName string
	var err error
	err = database.DB.QueryRow(`
		SELECT COLUMN_NAME
		FROM INFORMATION_SCHEMA.COLUMNS
		WHERE TABLE_SCHEMA = DATABASE()
		AND TABLE_NAME = 'order_items'
		AND COLUMN_NAME = 'service'
	`).Scan(&columnName)
	if err == sql.ErrNoRows {
		_, err = database.DB.Exec(`ALTER TABLE order_items ADD COLUMN service VARCHAR(255) NOT NULL DEFAULT ''`)
		if err != nil {
			log.Fatal("Gagal menambahkan kolom service ke order_items:", err)
		}
	} else if err != nil {
		log.Fatal("Gagal memeriksa kolom service pada order_items:", err)
	}

	_, err = database.DB.Exec(`
		CREATE TABLE IF NOT EXISTS user_vouchers (
			id INT AUTO_INCREMENT PRIMARY KEY,
			user_id VARCHAR(255) NOT NULL,
			code VARCHAR(100) NOT NULL,
			discount INT NOT NULL,
			is_used BOOLEAN NOT NULL DEFAULT FALSE,
			created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
			UNIQUE KEY unique_user_reward (user_id)
		)
	`)

	if err != nil {
		log.Fatal("Gagal buat tabel user_vouchers:", err)
	}

	r := gin.Default()

	// GET PRODUCTS
	r.GET("/products", func(c *gin.Context) {

		rows, err := database.DB.Query(`
			SELECT id, category_id, merk, price, stock, image
			FROM products
		`)

		if err != nil {
			c.JSON(500, gin.H{
				"error": err.Error(),
			})
			return
		}

		var products []Product

		for rows.Next() {

			var product Product

			rows.Scan(
				&product.ID,
				&product.CategoryID,
				&product.Merk,
				&product.Price,
				&product.Stock,
				&product.Image,
			)

			products = append(products, product)
		}

		c.JSON(http.StatusOK, products)

	})

	r.POST("/payment", handler.CreatePayment)

	r.POST("/orders", func(c *gin.Context) {

		var order Order
		var err error

		// =========================
		// BIND JSON
		// =========================
		err = c.ShouldBindJSON(&order)
		log.Printf("ORDER MASUK: %+v\n", order)
		log.Println("IDEMPOTENCY:", order.IdempotencyKey)

		if err != nil {

			log.Println("BIND ERROR:", err)

			c.JSON(400, gin.H{
				"error": err.Error(),
			})

			return
		}

		log.Printf("ORDER MASUK: %+v\n", order)

		// =========================
		// IDEMPOTENCY CHECK
		// =========================
		if order.IdempotencyKey != "" {

			var existingID int

			err := database.DB.QueryRow(`
			SELECT id
			FROM orders
			WHERE idempotency_key=?
			LIMIT 1
		`,
				order.IdempotencyKey,
			).Scan(&existingID)

			if err == nil {

				c.JSON(200, gin.H{
					"success":  true,
					"message":  "Duplicate request",
					"order_id": existingID,
				})

				return
			}
		}

		// =========================
		// CEK ORDER PENDING
		// =========================
		var existingOrderID int
		var existingMidtransID string
		var existingPaymentURL string

		err = database.DB.QueryRow(`
		SELECT id, midtrans_order_id, payment_url
		FROM orders
		WHERE user_id=?
		AND payment_status='pending'
		ORDER BY id DESC
		LIMIT 1
	`,
			order.UserID,
		).Scan(
			&existingOrderID,
			&existingMidtransID,
			&existingPaymentURL,
		)

		if err == nil {

			c.JSON(400, gin.H{
				"success":           false,
				"message":           "Masih ada pembayaran pending",
				"order_id":          existingOrderID,
				"midtrans_order_id": existingMidtransID,
				"payment_url":       existingPaymentURL,
			})

			return
		}

		if order.VoucherCode != "" {

			var voucherDiscount int
			var isUsed bool

			err := database.DB.QueryRow(`
	SELECT discount, is_used
	FROM user_vouchers
	WHERE user_id = ?
	AND code = ?
	LIMIT 1
`,
				order.UserID,
				order.VoucherCode,
			).Scan(
				&voucherDiscount,
				&isUsed,
			)

			if err != nil {

				c.JSON(400, gin.H{
					"error": "Voucher tidak ditemukan",
				})

				return
			}

			if isUsed {

				c.JSON(400, gin.H{
					"error": "Voucher sudah digunakan",
				})

				return
			}

			if voucherDiscount != order.VoucherDiscount {

				c.JSON(400, gin.H{
					"error": "Diskon voucher tidak valid",
				})

				return
			}
		}

		// =========================
		// BEGIN TX
		// =========================
		tx, err := database.DB.Begin()

		if err != nil {

			c.JSON(500, gin.H{
				"error": "Gagal begin transaction",
			})

			return
		}

		// =========================
		// INSERT ORDER
		// =========================
		result, err := tx.Exec(`
		INSERT INTO orders
		(
			user_id,
			payment_method_id,
			payment_channel,
			midtrans_order_id,
			total,
			voucher_code,
			voucher_discount,
			status,
			payment_status,
			idempotency_key
		)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
		`,
			order.UserID,
			order.PaymentMethodID,
			order.PaymentChannel,
			order.MidtransOrderID,
			order.Total,
			order.VoucherCode,
			order.VoucherDiscount,
			"Diproses",
			"pending",
			order.IdempotencyKey,
		)

		if err != nil {

			tx.Rollback()

			log.Println("INSERT ORDER ERROR:", err)

			c.JSON(500, gin.H{
				"error": err.Error(),
			})

			return
		}

		orderID, _ := result.LastInsertId()

		log.Println("ORDER BERHASIL DIBUAT:", orderID)

		// =========================
		// INSERT ITEMS
		// =========================
		for _, item := range order.Items {

			var stock int
			var reservedStock int

			err := tx.QueryRow(`
			SELECT stock,reserved_stock
			FROM products
			WHERE id=?
			FOR UPDATE
		`,
				item.ProductID,
			).Scan(
				&stock,
				&reservedStock,
			)

			if err != nil {

				tx.Rollback()

				c.JSON(500, gin.H{
					"error": err.Error(),
				})

				return
			}

			availableStock := stock - reservedStock

			if item.Service != "Isi Ulang" {
				if availableStock < item.Qty {

					tx.Rollback()

					c.JSON(400, gin.H{
						"error": "Stock tidak cukup",
					})

					return
				}
			}

			// INSERT ORDER ITEM
			_, err = tx.Exec(`
			INSERT INTO order_items
			(
				order_id,
				product_id,
				qty,
				subtotal,
				service
			)
			VALUES (?, ?, ?, ?, ?)
		`,
				orderID,
				item.ProductID,
				item.Qty,
				item.Subtotal,
				item.Service,
			)

			if err != nil {

				tx.Rollback()

				c.JSON(500, gin.H{
					"error": err.Error(),
				})

				return
			}

			// RESERVE STOCK
			if item.Service != "Isi Ulang" {
				_, err = tx.Exec(`
			UPDATE products
			SET reserved_stock = reserved_stock + ?
			WHERE id=?
		`,
					item.Qty,
					item.ProductID,
				)

				if err != nil {
					tx.Rollback()

					c.JSON(500, gin.H{
						"error": err.Error(),
					})

					return
				}
			}

			if err != nil {

				tx.Rollback()

				c.JSON(500, gin.H{
					"error": err.Error(),
				})

				return
			}
		}

		// =========================
		// COMMIT
		// =========================
		err = tx.Commit()

		if err != nil {

			c.JSON(500, gin.H{
				"error": "Gagal commit transaction",
			})

			return
		}

		c.JSON(200, gin.H{
			"message":  "Order berhasil dibuat",
			"order_id": orderID,
		})
	})

	// GET ORDERS BY USER
	r.GET("/orders/:user_id", func(c *gin.Context) {

		userID := c.Param("user_id")

		rows, err := database.DB.Query(`
		SELECT id, total, status, created_at
		FROM orders
		WHERE user_id = ?
		ORDER BY id DESC
	`, userID)

		if err != nil {
			c.JSON(500, gin.H{
				"error": err.Error(),
			})
			return
		}

		var orders []OrderResponse

		for rows.Next() {

			var order OrderResponse

			rows.Scan(
				&order.ID,
				&order.Total,
				&order.Status,
				&order.CreatedAt,
			)

			orders = append(orders, order)
		}

		c.JSON(200, orders)
	})

	r.GET("/user-vouchers/:user_id", func(c *gin.Context) {
		userID := c.Param("user_id")

		rows, err := database.DB.Query(`
		SELECT id, code, discount, is_used, created_at
		FROM user_vouchers
		WHERE user_id = ?
		AND is_used = FALSE
		ORDER BY created_at DESC
	`, userID)

		if err != nil {
			c.JSON(500, gin.H{"error": err.Error()})
			return
		}

		defer rows.Close()

		var vouchers []gin.H

		for rows.Next() {
			var id int
			var code string
			var discount int
			var isUsed bool
			var createdAt string

			errs := rows.Scan(&id, &code, &discount, &isUsed, &createdAt)

			if errs != nil {
				continue
			}

			vouchers = append(vouchers, gin.H{
				"id":         id,
				"code":       code,
				"discount":   discount,
				"is_used":    isUsed,
				"created_at": createdAt,
			})
		}

		c.JSON(200, vouchers)
	})

	// GET DETAIL ORDER
	r.GET("/orders/detail/:id", func(c *gin.Context) {

		orderID := c.Param("id")

		// GET ORDER
		var order OrderDetailResponse

		err := database.DB.QueryRow(`
		SELECT id, status, total
		FROM orders
		WHERE id = ?
	`, orderID).Scan(
			&order.ID,
			&order.Status,
			&order.Total,
		)

		if err != nil {
			c.JSON(500, gin.H{
				"error": err.Error(),
			})
			return
		}

		// GET ITEMS
		rows, err := database.DB.Query(`
		SELECT p.merk, oi.qty, oi.subtotal
		FROM order_items oi
		JOIN products p ON p.id = oi.product_id
		WHERE oi.order_id = ?
	`, orderID)

		if err != nil {
			c.JSON(500, gin.H{
				"error": err.Error(),
			})
			return
		}

		var items []OrderDetailItem

		for rows.Next() {

			var item OrderDetailItem

			rows.Scan(
				&item.Merk,
				&item.Qty,
				&item.Subtotal,
			)

			items = append(items, item)
		}

		order.Items = items

		c.JSON(200, order)
	})

	r.GET("/orders", func(c *gin.Context) {

		rows, err := database.DB.Query(`
		SELECT id, total, status, created_at
		FROM orders
		ORDER BY id DESC
	`)

		if err != nil {
			c.JSON(500, gin.H{
				"error": err.Error(),
			})
			return
		}

		defer rows.Close()

		var orders []gin.H

		for rows.Next() {

			var id int
			var total int
			var status string
			var createdAt string

			rows.Scan(
				&id,
				&total,
				&status,
				&createdAt,
			)

			orders = append(orders, gin.H{
				"id":         id,
				"total":      total,
				"status":     status,
				"created_at": createdAt,
			})
		}

		c.JSON(200, orders)
	})

	r.POST("/profile", func(c *gin.Context) {

		var user User

		if err := c.ShouldBindJSON(&user); err != nil {

			c.JSON(400, gin.H{
				"error": err.Error(),
			})

			return
		}

		_, err := database.DB.Exec(`
		INSERT INTO users
		(firebase_uid, email, name, phone, address)
		VALUES (?, ?, ?, ?, ?)

		ON DUPLICATE KEY UPDATE
		name = VALUES(name),
		phone = VALUES(phone),
		address = VALUES(address)
	`,
			user.FirebaseUID,
			user.Email,
			user.Name,
			user.Phone,
			user.Address,
		)

		if err != nil {

			c.JSON(500, gin.H{
				"error": err.Error(),
			})

			return
		}

		c.JSON(200, gin.H{
			"message": "Profile berhasil disimpan",
		})
	})

	r.GET("/profile/:uid", func(c *gin.Context) {

		uid := c.Param("uid")

		var user User

		err := database.DB.QueryRow(`
		SELECT firebase_uid, email, name, phone, address
		FROM users
		WHERE firebase_uid = ?
	`, uid).Scan(
			&user.FirebaseUID,
			&user.Email,
			&user.Name,
			&user.Phone,
			&user.Address,
		)

		if err != nil {

			c.JSON(404, gin.H{
				"error": "Profile tidak ditemukan",
			})

			return
		}

		c.JSON(200, user)
	})

	// UPDATE STATUS ORDER
	r.PUT("/orders/status/:id", func(c *gin.Context) {

		id := c.Param("id")

		var body struct {
			Status string `json:"status"`
		}

		if err := c.ShouldBindJSON(&body); err != nil {

			c.JSON(400, gin.H{
				"error": err.Error(),
			})

			return
		}

		_, err := database.DB.Exec(`
		UPDATE orders
		SET status = ?
		WHERE id = ?
	`,
			body.Status,
			id,
		)

		if err != nil {

			c.JSON(500, gin.H{
				"error": err.Error(),
			})

			return
		}

		// =========================
		// NOTIFIKASI FIREBASE
		// =========================

		var token string
		var name string

		err = database.DB.QueryRow(`
		SELECT
			u.fcm_token,
			u.name
		FROM orders o
		JOIN users u
		ON u.firebase_uid = o.user_id
		WHERE o.id = ?
	`,
			id,
		).Scan(
			&token,
			&name,
		)

		if err == nil && token != "" {

			title := "Status Pesanan"

			bodyNotif := ""

			if body.Status == "Diproses" {

				bodyNotif =
					"Halo " + name +
						", pesanan anda sedang diproses"

			} else if body.Status == "Dikirim" {

				bodyNotif =
					"Halo " + name +
						", pesanan anda sedang dikirim"

			} else if body.Status == "Selesai" {

				bodyNotif =
					"Halo " + name +
						", pesanan anda telah selesai"
			}

			database.SendNotification(
				token,
				title,
				bodyNotif,
			)
		}

		// =========================

		c.JSON(200, gin.H{
			"message": "Status berhasil diupdate",
		})
	})

	// CREATE USER
	r.POST("/users", func(c *gin.Context) {

		var body struct {
			FirebaseUID string `json:"firebase_uid"`
			Email       string `json:"email"`
			Name        string `json:"name"`
			Phone       string `json:"phone"`
			Address     string `json:"address"`
			FCMToken    string `json:"fcm_token"`
		}

		if err := c.ShouldBindJSON(&body); err != nil {

			c.JSON(400, gin.H{
				"error": err.Error(),
			})

			return
		}

		var count int

		database.DB.QueryRow(`
		SELECT COUNT(*)
		FROM users
		WHERE firebase_uid = ?
	`, body.FirebaseUID).Scan(&count)

		// INSERT USER BARU
		if count == 0 {

			_, err := database.DB.Exec(`
			INSERT INTO users
			(firebase_uid, email, name, phone, address, role, fcm_token)
			VALUES (?, ?, ?, ?, ?, ?, ?)
		`,
				body.FirebaseUID,
				body.Email,
				body.Name,
				body.Phone,
				body.Address,
				"customer",
				body.FCMToken,
			)

			if err != nil {

				c.JSON(500, gin.H{
					"error": err.Error(),
				})

				return
			}
		} else {

			// UPDATE TOKEN SAJA
			_, err := database.DB.Exec(`
	UPDATE users
	SET fcm_token = ?
	WHERE firebase_uid = ?
`,
				body.FCMToken,
				body.FirebaseUID,
			)

			if err != nil {

				c.JSON(500, gin.H{
					"error": err.Error(),
				})

				return
			}
		}

		c.JSON(200, gin.H{
			"message": "User berhasil",
		})
	})

	// GET ROLE USER
	r.GET("/users/:uid", func(c *gin.Context) {

		uid := c.Param("uid")

		var user struct {
			Role string `json:"role"`
		}

		err := database.DB.QueryRow(`
		SELECT role
		FROM users
		WHERE firebase_uid = ?
	`, uid).Scan(
			&user.Role,
		)

		if err != nil {

			c.JSON(404, gin.H{
				"error": "User tidak ditemukan",
			})

			return
		}

		c.JSON(200, user)
	})

	// CREATE PRODUCT
	r.POST("/products", func(c *gin.Context) {

		var product Product

		if err := c.ShouldBindJSON(&product); err != nil {

			c.JSON(400, gin.H{
				"error": err.Error(),
			})

			return
		}

		_, err := database.DB.Exec(`
		INSERT INTO products
		(category_id, merk, price, stock, image)
		VALUES (?, ?, ?, ?, ?)
	`,
			product.CategoryID,
			product.Merk,
			product.Price,
			product.Stock,
			product.Image,
		)

		if err != nil {

			c.JSON(500, gin.H{
				"error": err.Error(),
			})

			return
		}

		c.JSON(200, gin.H{
			"message": "Produk berhasil ditambahkan",
		})
	})

	// UPDATE PRODUCT
	r.PUT("/products/:id", func(c *gin.Context) {

		id := c.Param("id")

		var product Product

		if err := c.ShouldBindJSON(&product); err != nil {

			c.JSON(400, gin.H{
				"error": err.Error(),
			})

			return
		}

		_, err := database.DB.Exec(`
		UPDATE products
		SET
			category_id = ?,
			merk = ?,
			price = ?,
			stock = ?,
			image = ?
		WHERE id = ?
	`,
			product.CategoryID,
			product.Merk,
			product.Price,
			product.Stock,
			product.Image,
			id,
		)

		if err != nil {

			c.JSON(500, gin.H{
				"error": err.Error(),
			})

			return
		}

		c.JSON(200, gin.H{
			"message": "Produk berhasil diupdate",
		})
	})

	// DELETE PRODUCT
	r.DELETE("/products/:id", func(c *gin.Context) {

		id := c.Param("id")

		_, err := database.DB.Exec(`
		DELETE FROM products
		WHERE id = ?
	`, id)

		if err != nil {

			c.JSON(500, gin.H{
				"error": err.Error(),
			})

			return
		}

		c.JSON(200, gin.H{
			"message": "Produk berhasil dihapus",
		})
	})

	// GET ORDER UNTUK KURIR
	r.GET("/kurir/orders", func(c *gin.Context) {

		rows, err := database.DB.Query(`
		SELECT
			o.id,
			o.total,
			o.status,
			o.created_at,
			u.name,
			u.phone,
			u.address
		FROM orders o
		JOIN users u ON u.firebase_uid = o.user_id
		WHERE o.status != 'Selesai'
		ORDER BY o.id DESC
	`)

		if err != nil {

			c.JSON(500, gin.H{
				"error": err.Error(),
			})

			return
		}

		defer rows.Close()

		orders := []gin.H{}

		for rows.Next() {

			var id int
			var total int
			var status string
			var createdAt string
			var name string
			var phone string
			var address string

			rows.Scan(
				&id,
				&total,
				&status,
				&createdAt,
				&name,
				&phone,
				&address,
			)

			orders = append(orders, gin.H{
				"id":         id,
				"total":      total,
				"status":     status,
				"created_at": createdAt,
				"name":       name,
				"phone":      phone,
				"address":    address,
			})
		}

		c.JSON(200, orders)
	})

	// DASHBOARD ANALYTICS
	r.GET("/dashboard", func(c *gin.Context) {

		var totalOrders int
		var totalRevenue int
		var totalProducts int
		var totalCustomers int

		// TOTAL ORDER
		database.DB.QueryRow(`
		SELECT COUNT(*)
		FROM orders
	`).Scan(&totalOrders)

		// TOTAL REVENUE
		database.DB.QueryRow(`
		SELECT IFNULL(SUM(total), 0)
		FROM orders
		WHERE status != 'Dibatalkan'
	`).Scan(&totalRevenue)

		// TOTAL PRODUCT
		database.DB.QueryRow(`
		SELECT COUNT(*)
		FROM products
	`).Scan(&totalProducts)

		// TOTAL CUSTOMER
		database.DB.QueryRow(`
		SELECT COUNT(*)
		FROM users
		WHERE role = 'customer'
	`).Scan(&totalCustomers)

		// PRODUK TERLARIS
		rows, err := database.DB.Query(`
		SELECT p.merk, SUM(oi.qty) as total_terjual
		FROM order_items oi
		JOIN products p ON p.id = oi.product_id
		GROUP BY oi.product_id
		ORDER BY total_terjual DESC
		LIMIT 5
	`)

		if err != nil {

			c.JSON(500, gin.H{
				"error": err.Error(),
			})

			return
		}

		defer rows.Close()

		var bestProducts []gin.H

		for rows.Next() {

			var merk string
			var total int

			rows.Scan(
				&merk,
				&total,
			)

			bestProducts = append(bestProducts, gin.H{
				"merk":  merk,
				"total": total,
			})
		}

		c.JSON(200, gin.H{
			"total_orders":    totalOrders,
			"total_revenue":   totalRevenue,
			"total_products":  totalProducts,
			"total_customers": totalCustomers,
			"best_products":   bestProducts,
		})
	})

	// GET ALL VOUCHERS
	r.GET("/vouchers", func(c *gin.Context) {

		rows, err := database.DB.Query(`
		SELECT id, code, discount, is_active
		FROM vouchers
		ORDER BY id DESC
	`)

		if err != nil {

			c.JSON(500, gin.H{
				"error": err.Error(),
			})

			return
		}

		defer rows.Close()

		var vouchers []Voucher

		for rows.Next() {

			var voucher Voucher

			rows.Scan(
				&voucher.ID,
				&voucher.Code,
				&voucher.Discount,
				&voucher.IsActive,
			)

			vouchers = append(vouchers, voucher)
		}

		c.JSON(200, vouchers)
	})

	// CREATE VOUCHER
	r.POST("/vouchers", func(c *gin.Context) {

		var voucher Voucher

		if err := c.ShouldBindJSON(&voucher); err != nil {

			c.JSON(400, gin.H{
				"error": err.Error(),
			})

			return
		}

		if voucher.Code == "" {
			voucher.Code = generateVoucherCode()
		}

		_, err := database.DB.Exec(`
		INSERT INTO vouchers
		(code, discount, is_active)
		VALUES (?, ?, ?)
	`,
			voucher.Code,
			voucher.Discount,
			true,
		)

		if err != nil {

			c.JSON(500, gin.H{
				"error": err.Error(),
			})

			return
		}

		c.JSON(200, gin.H{
			"message": "Voucher berhasil dibuat",
			"code":    voucher.Code,
		})
	})

	// ASSIGN VOUCHER TO CUSTOMER
	r.POST("/user-vouchers/assign", func(c *gin.Context) {

		type assignRequest struct {
			UserUID      string   `json:"user_uid"`
			Email        string   `json:"email"`
			AssignAll    bool     `json:"assign_all"`
			VoucherCodes []string `json:"voucher_codes"`
		}

		var req assignRequest

		if err := c.ShouldBindJSON(&req); err != nil {
			c.JSON(400, gin.H{
				"error": err.Error(),
			})
			return
		}

		if len(req.VoucherCodes) == 0 {
			c.JSON(400, gin.H{
				"error": "Voucher wajib dipilih",
			})
			return
		}

		code := req.VoucherCodes[0]

		var voucher Voucher

		err := database.DB.QueryRow(`
		SELECT id, code, discount, is_active
		FROM vouchers
		WHERE code=?
	`,
			code,
		).Scan(
			&voucher.ID,
			&voucher.Code,
			&voucher.Discount,
			&voucher.IsActive,
		)

		if err != nil {
			c.JSON(404, gin.H{
				"error": "Voucher tidak ditemukan",
			})
			return
		}

		// =====================================
		// ASSIGN KE SEMUA CUSTOMER
		// =====================================
		if req.AssignAll {

			rows, err := database.DB.Query(`
			SELECT firebase_uid
			FROM users
			WHERE role='customer'
		`)

			if err != nil {
				c.JSON(500, gin.H{
					"error": err.Error(),
				})
				return
			}

			defer rows.Close()

			for rows.Next() {

				var uid string

				rows.Scan(&uid)

				_, err := database.DB.Exec(`
				INSERT INTO user_vouchers
				(user_id, code, discount, is_used)
				VALUES (?, ?, ?, false)
			`,
					uid,
					voucher.Code,
					voucher.Discount,
				)

				if err != nil {
					log.Println("ASSIGN ALL ERROR:", err)
				}
			}

			c.JSON(200, gin.H{
				"message": "Voucher berhasil diberikan ke semua customer",
			})

			return
		}

		// =====================================
		// ASSIGN KE CUSTOMER TERTENTU
		// =====================================

		if req.Email == "" {
			c.JSON(400, gin.H{
				"error": "Email customer wajib diisi",
			})
			return
		}

		var userID string

		err = database.DB.QueryRow(`
		SELECT firebase_uid
		FROM users
		WHERE email=?
	`,
			req.Email,
		).Scan(&userID)

		if err != nil {

			c.JSON(404, gin.H{
				"error": "Customer tidak ditemukan",
			})

			return
		}

		_, err = database.DB.Exec(`
		INSERT INTO user_vouchers
		(user_id, code, discount, is_used)
		VALUES (?, ?, ?, false)
	`,
			userID,
			voucher.Code,
			voucher.Discount,
		)

		if err != nil {

			c.JSON(500, gin.H{
				"error": err.Error(),
			})

			return
		}

		c.JSON(200, gin.H{
			"message": "Voucher berhasil diberikan",
		})
	})

	// GET VOUCHER BY CODE
	r.GET("/voucher/:code", func(c *gin.Context) {

		code := c.Param("code")

		var voucher Voucher

		err := database.DB.QueryRow(`
		SELECT id, code, discount, is_active
		FROM vouchers
		WHERE code = ?
	`,
			code,
		).Scan(
			&voucher.ID,
			&voucher.Code,
			&voucher.Discount,
			&voucher.IsActive,
		)

		if err != nil {

			c.JSON(404, gin.H{
				"error": "Voucher tidak ditemukan",
			})

			return
		}

		if !voucher.IsActive {

			c.JSON(400, gin.H{
				"error": "Voucher tidak aktif",
			})

			return
		}

		c.JSON(200, voucher)
	})

	// DELETE VOUCHER
	r.DELETE("/vouchers/:id", func(c *gin.Context) {

		id := c.Param("id")

		_, err := database.DB.Exec(`
		DELETE FROM vouchers
		WHERE id = ?
	`, id)

		if err != nil {

			c.JSON(500, gin.H{
				"error": err.Error(),
			})

			return
		}

		c.JSON(200, gin.H{
			"message": "Voucher berhasil dihapus",
		})
	})

	// GET REPORT
	r.GET("/reports", func(c *gin.Context) {

		rows, err := database.DB.Query(`
		SELECT
			o.id,
			u.name,
			o.total,
			o.status,
			o.created_at
		FROM orders o
		JOIN users u
		ON u.firebase_uid = o.user_id
		ORDER BY o.id DESC
	`)

		if err != nil {

			c.JSON(500, gin.H{
				"error": err.Error(),
			})

			return
		}

		defer rows.Close()

		var reports []gin.H

		for rows.Next() {

			var id int
			var name string
			var total int
			var status string
			var createdAt string

			rows.Scan(
				&id,
				&name,
				&total,
				&status,
				&createdAt,
			)

			reports = append(reports, gin.H{
				"id":         id,
				"name":       name,
				"total":      total,
				"status":     status,
				"created_at": createdAt,
			})
		}

		c.JSON(200, reports)
	})

	r.POST("/midtrans/callback", func(c *gin.Context) {

		log.Println("CALLBACK MASUK")

		var notification map[string]interface{}

		if err := c.BindJSON(&notification); err != nil {

			c.JSON(400, gin.H{
				"error": err.Error(),
			})

			return
		}

		log.Println("FULL NOTIFICATION:", notification)

		// =========================
		// AMBIL DATA CALLBACK
		// =========================
		orderID := notification["order_id"].(string)
		statusCode := notification["status_code"].(string)
		grossAmount := notification["gross_amount"].(string)
		signatureKey := notification["signature_key"].(string)
		transactionStatus := notification["transaction_status"].(string)

		log.Println("CALLBACK ORDER ID:", orderID)
		log.Println("CALLBACK STATUS:", transactionStatus)

		// =========================
		// VALIDASI SIGNATURE
		// =========================
		serverKey := os.Getenv("MIDTRANS_SERVER_KEY")

		rawSignature := orderID + statusCode + grossAmount + serverKey

		hash := sha512.Sum512([]byte(rawSignature))

		expectedSignature := hex.EncodeToString(hash[:])

		if signatureKey != expectedSignature {

			log.Println("SIGNATURE INVALID")

			c.JSON(403, gin.H{
				"message": "Invalid signature",
			})

			return
		}

		log.Println("SIGNATURE VALID")

		// =========================
		// HANDLE SUCCESS PAYMENT
		// =========================
		if transactionStatus == "settlement" ||
			transactionStatus == "capture" {

			// BEGIN TRANSACTION
			tx, err := database.DB.Begin()

			if err != nil {

				log.Println("BEGIN TX ERROR:", err)

				c.JSON(500, gin.H{
					"message": "Gagal begin transaction",
				})

				return
			}

			// UPDATE STATUS KE PAID
			result, err := tx.Exec(`
			UPDATE orders
			SET payment_status='paid'
			WHERE midtrans_order_id=?
			AND payment_status!='paid'
		`, orderID)

			if err != nil {

				tx.Rollback()

				log.Println("UPDATE PAID ERROR:", err)

				c.JSON(500, gin.H{
					"message": "Gagal update paid",
				})

				return
			}

			rows, _ := result.RowsAffected()

			var voucherCode string

			err = tx.QueryRow(`
	SELECT voucher_code
	FROM orders
	WHERE midtrans_order_id = ?
`,
				orderID,
			).Scan(&voucherCode)

			if err != nil && err != sql.ErrNoRows {

				tx.Rollback()

				log.Println("GET VOUCHER ERROR:", err)

				c.JSON(500, gin.H{
					"message": "Gagal mengambil voucher",
				})

				return
			}

			if voucherCode != "" {

				_, err = tx.Exec(`
	UPDATE user_vouchers
	SET is_used = true
	WHERE code = ?
`,
					voucherCode,
				)

				if err != nil {

					tx.Rollback()

					log.Println("UPDATE VOUCHER USED ERROR:", err)

					c.JSON(500, gin.H{
						"message": "Gagal update voucher",
					})

					return
				}

				log.Println("VOUCHER DIGUNAKAN:", voucherCode)
			}

			log.Println("ROWS UPDATED:", rows)

			// CALLBACK DUPLICATE
			if rows == 0 {

				tx.Rollback()

				log.Println("ORDER SUDAH PAID / DUPLICATE CALLBACK")

				c.JSON(200, gin.H{
					"message": "already processed",
				})

				return
			}

			var userID string
			err = tx.QueryRow(`
			SELECT user_id
			FROM orders
			WHERE midtrans_order_id = ?
		`, orderID).Scan(&userID)

			if err != nil {
				tx.Rollback()
				log.Println("GET USER ERROR:", err)
				c.JSON(500, gin.H{
					"message": "Gagal mengambil data pengguna",
				})
				return
			}

			// =========================
			// HITUNG TOTAL ORDER PAID
			// =========================
			var paidCount int

			err = tx.QueryRow(`
	SELECT COUNT(*)
	FROM orders
	WHERE user_id = ?
	AND payment_status = 'paid'
`, userID).Scan(&paidCount)

			if err != nil {

				tx.Rollback()

				log.Println("COUNT PAID ORDERS ERROR:", err)

				c.JSON(500, gin.H{
					"message": "Gagal menghitung transaksi",
				})

				return
			}

			log.Println("TOTAL PAID ORDER:", paidCount)

			// =========================
			// VOUCHER SETIAP 5 ORDER
			// =========================
			if paidCount > 0 && paidCount%5 == 0 {

				// CEK APAKAH SUDAH PERNAH DAPAT
				var existingVoucher int

				err = tx.QueryRow(`
		SELECT COUNT(*)
		FROM user_vouchers
		WHERE user_id = ?
	`, userID).Scan(&existingVoucher)

				if err != nil {

					tx.Rollback()

					log.Println("CHECK VOUCHER ERROR:", err)

					c.JSON(500, gin.H{
						"message": "Gagal cek voucher",
					})

					return
				}

				// HANYA BUAT JIKA BELUM ADA
				expectedVoucher := paidCount / 5

				if existingVoucher < expectedVoucher {

					code := generateVoucherCode()

					_, err = tx.Exec(`
			INSERT INTO user_vouchers
			(user_id, code, discount, is_used)
			VALUES (?, ?, ?, false)
		`,
						userID,
						code,
						10000,
					)

					if err != nil {

						tx.Rollback()

						log.Println("CREATE REWARD VOUCHER ERROR:", err)

						c.JSON(500, gin.H{
							"message": "Gagal membuat voucher",
						})

						return
					}

					log.Println("VOUCHER REWARD DIBUAT:", code)
				}
			}

			// REDUCE STOCK
			err = service.ReduceStockByOrderTx(tx, orderID)

			if err != nil {

				tx.Rollback()

				log.Println("REDUCE STOCK ERROR:", err)

				c.JSON(500, gin.H{
					"message": "Gagal reduce stock",
				})

				return
			}

			// COMMIT
			err = tx.Commit()

			if err != nil {

				log.Println("COMMIT ERROR:", err)

				c.JSON(500, gin.H{
					"message": "Gagal commit transaction",
				})

				return
			}

			log.Println("STOCK BERHASIL DIKURANGI")
		}

		// =========================
		// HANDLE EXPIRE
		// =========================
		if transactionStatus == "expire" {

			tx, err := database.DB.Begin()

			if err != nil {

				log.Println("BEGIN TX EXPIRE ERROR:", err)

				return
			}

			result, err := tx.Exec(`
		UPDATE orders
		SET
			payment_status='expired',
			payment_url=NULL
		WHERE midtrans_order_id=?
		AND payment_status='pending'
	`, orderID)

			if err != nil {

				tx.Rollback()

				log.Println("UPDATE EXPIRED ERROR:", err)

				return
			}

			rows, _ := result.RowsAffected()

			log.Println("ROWS UPDATED EXPIRED:", rows)

			// hanya release kalau benar2 berubah
			if rows > 0 {

				err = service.ReleaseReservedStockTx(
					tx,
					orderID,
				)

				if err != nil {

					tx.Rollback()

					log.Println("RELEASE STOCK ERROR:", err)

					return
				}
			}

			err = tx.Commit()

			if err != nil {

				log.Println("COMMIT EXPIRE ERROR:", err)

				return
			}
		}

		// =========================
		// HANDLE CANCEL
		// =========================
		if transactionStatus == "cancel" {

			tx, err := database.DB.Begin()

			if err != nil {

				log.Println("BEGIN TX CANCEL ERROR:", err)

				return
			}

			result, err := tx.Exec(`
		UPDATE orders
		SET
			payment_status='cancelled',
			payment_url=NULL
		WHERE midtrans_order_id=?
		AND payment_status='pending'
	`, orderID)

			if err != nil {

				tx.Rollback()

				log.Println("UPDATE CANCEL ERROR:", err)

				return
			}

			rows, _ := result.RowsAffected()

			log.Println("ROWS UPDATED CANCEL:", rows)

			// hanya release stock jika status benar-benar berubah
			if rows > 0 {

				err = service.ReleaseReservedStockTx(
					tx,
					orderID,
				)

				if err != nil {

					tx.Rollback()

					log.Println("RELEASE STOCK CANCEL ERROR:", err)

					return
				}
			}

			err = tx.Commit()

			if err != nil {

				log.Println("COMMIT CANCEL ERROR:", err)

				return
			}

			log.Println("CANCEL BERHASIL DIPROSES")
		}

		// =========================
		// HANDLE DENY
		// =========================
		if transactionStatus == "deny" {

			tx, err := database.DB.Begin()

			if err != nil {

				log.Println("BEGIN TX DENY ERROR:", err)

				return
			}

			result, err := tx.Exec(`
		UPDATE orders
		SET
			payment_status='failed',
			payment_url=NULL
		WHERE midtrans_order_id=?
		AND payment_status='pending'
	`, orderID)

			if err != nil {

				tx.Rollback()

				log.Println("UPDATE DENY ERROR:", err)

				return
			}

			rows, _ := result.RowsAffected()

			log.Println("ROWS UPDATED DENY:", rows)

			if rows > 0 {

				err = service.ReleaseReservedStockTx(
					tx,
					orderID,
				)

				if err != nil {

					tx.Rollback()

					log.Println("RELEASE STOCK DENY ERROR:", err)

					return
				}
			}

			err = tx.Commit()

			if err != nil {

				log.Println("COMMIT DENY ERROR:", err)

				return
			}
		}

		// =========================
		// HANDLE PENDING
		// =========================
		if transactionStatus == "pending" {

			result, err := database.DB.Exec(`
			UPDATE orders
			SET payment_status='pending'
			WHERE midtrans_order_id=?
		`, orderID)

			if err != nil {

				log.Println("UPDATE PENDING ERROR:", err)

			} else {

				rows, _ := result.RowsAffected()

				log.Println("ROWS UPDATED PENDING:", rows)
			}
		}

		c.JSON(200, gin.H{
			"message": "callback received",
		})
	})

	r.GET("/payment/retry/:user_id", func(c *gin.Context) {

		userID := c.Param("user_id")

		var order struct {
			ID              int
			MidtransOrderID string
			PaymentURL      string
			Total           int
			PaymentStatus   string
		}

		err := database.DB.QueryRow(`
		SELECT
			id,
			midtrans_order_id,
			payment_url,
			total,
			payment_status
		FROM orders
		WHERE user_id=?
		AND payment_status='pending'
		AND payment_url IS NOT NULL
		ORDER BY id DESC
		LIMIT 1
	`,
			userID,
		).Scan(
			&order.ID,
			&order.MidtransOrderID,
			&order.PaymentURL,
			&order.Total,
			&order.PaymentStatus,
		)

		if err != nil {

			c.JSON(404, gin.H{
				"success": false,
				"message": "Tidak ada pending payment",
			})

			return
		}

		c.JSON(200, gin.H{
			"success": true,
			"data": gin.H{
				"order_id":          order.ID,
				"midtrans_order_id": order.MidtransOrderID,
				"payment_url":       order.PaymentURL,
				"total":             order.Total,
				"payment_status":    order.PaymentStatus,
			},
		})
	})

	r.Run(":8080")
}
