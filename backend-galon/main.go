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
	Modal      int    `json:"modal"`
	Stock      int    `json:"stock"`
	Image      string `json:"image"`
	SupplierID int    `json:"supplier_id"`
}

type Supplier struct {
	ID      int    `json:"id"`
	Name    string `json:"name"`
	Phone   string `json:"phone"`
	Address string `json:"address"`
}

type RewardSettings struct {
	Multiplier int `json:"multiplier"`
	Discount   int `json:"discount"`
}

type Rental struct {
	ID           int    `json:"id"`
	OrderID      int    `json:"order_id"`
	ProductID    int    `json:"product_id"`
	UserID       string `json:"user_id"`
	Merk         string `json:"merk"`
	Qty          int    `json:"qty"`
	Status       string `json:"status"`
	RentedAt     string `json:"rented_at"`
	ReturnedAt   string `json:"returned_at"`
	CustomerName string `json:"customer_name"`
	Notes        string `json:"notes"`
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

	Notes         string `json:"notes"`
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
	Name     string `json:"name"`
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

	// =========================
	// MIGRASI KOLOM ORDERS UNTUK TRANSAKSI KASIR (OFFLINE)
	// =========================
	ensureOrderColumn := func(column string, definition string) {
		var existing string
		errCol := database.DB.QueryRow(`
			SELECT COLUMN_NAME
			FROM INFORMATION_SCHEMA.COLUMNS
			WHERE TABLE_SCHEMA = DATABASE()
			AND TABLE_NAME = 'orders'
			AND COLUMN_NAME = ?
		`, column).Scan(&existing)

		if errCol == sql.ErrNoRows {
			_, errCol = database.DB.Exec(fmt.Sprintf("ALTER TABLE orders ADD COLUMN %s %s", column, definition))
			if errCol != nil {
				log.Fatalf("Gagal menambahkan kolom %s ke orders: %v", column, errCol)
			}
		} else if errCol != nil {
			log.Fatalf("Gagal memeriksa kolom %s pada orders: %v", column, errCol)
		}
	}

	ensureOrderColumn("customer_name", "VARCHAR(255) NOT NULL DEFAULT ''")
	ensureOrderColumn("customer_phone", "VARCHAR(50) NOT NULL DEFAULT ''")
	ensureOrderColumn("is_offline", "TINYINT NOT NULL DEFAULT 0")
	ensureOrderColumn("notes", "TEXT")

	// =========================
	// MIGRASI TABEL SUPPLIERS
	// =========================
	_, err = database.DB.Exec(`
		CREATE TABLE IF NOT EXISTS suppliers (
			id      INT AUTO_INCREMENT PRIMARY KEY,
			name    VARCHAR(255) NOT NULL,
			phone   VARCHAR(50)  NOT NULL DEFAULT '',
			address TEXT
		)
	`)
	if err != nil {
		log.Fatal("Gagal buat tabel suppliers:", err)
	}

	// Tambah kolom phone/address jika belum ada (migrasi backward-compat)
	ensureSupplierColumn := func(column string, definition string) {
		var existing string
		_ = database.DB.QueryRow(`
			SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS
			WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'suppliers' AND COLUMN_NAME = ?
		`, column).Scan(&existing)
		if existing == "" {
			database.DB.Exec(fmt.Sprintf("ALTER TABLE suppliers ADD COLUMN %s %s", column, definition))
		}
	}
	ensureSupplierColumn("phone", "VARCHAR(50) NOT NULL DEFAULT ''")
	ensureSupplierColumn("address", "TEXT")

	// =========================
	// MIGRASI TABEL REWARD_SETTINGS
	// =========================
	_, err = database.DB.Exec(`
		CREATE TABLE IF NOT EXISTS reward_settings (
			id         INT PRIMARY KEY DEFAULT 1,
			multiplier INT NOT NULL DEFAULT 5,
			discount   INT NOT NULL DEFAULT 2000
		)
	`)
	if err != nil {
		log.Fatal("Gagal buat tabel reward_settings:", err)
	}
	database.DB.Exec(`INSERT IGNORE INTO reward_settings (id, multiplier, discount) VALUES (1, 5, 2000)`)

	// =========================
	// MIGRASI KOLOM PRODUCTS (MODAL & SUPPLIER_ID)
	// =========================
	ensureProductColumn := func(column string, definition string) {
		var existing string
		errCol := database.DB.QueryRow(`
			SELECT COLUMN_NAME
			FROM INFORMATION_SCHEMA.COLUMNS
			WHERE TABLE_SCHEMA = DATABASE()
			AND TABLE_NAME = 'products'
			AND COLUMN_NAME = ?
		`, column).Scan(&existing)
		if errCol == sql.ErrNoRows {
			_, errCol = database.DB.Exec(fmt.Sprintf("ALTER TABLE products ADD COLUMN %s %s", column, definition))
			if errCol != nil {
				log.Fatalf("Gagal menambahkan kolom %s ke products: %v", column, errCol)
			}
		} else if errCol != nil {
			log.Fatalf("Gagal memeriksa kolom %s pada products: %v", column, errCol)
		}
	}
	ensureProductColumn("modal", "INT NOT NULL DEFAULT 0")
	ensureProductColumn("supplier_id", "INT NOT NULL DEFAULT 0")

	// =========================
	// MIGRASI TABEL RENTALS (PENCATATAN GALON SEWA)
	// =========================
	_, err = database.DB.Exec(`
		CREATE TABLE IF NOT EXISTS rentals (
			id          INT AUTO_INCREMENT PRIMARY KEY,
			order_id    INT NOT NULL,
			product_id  INT NOT NULL,
			user_id     VARCHAR(255) NOT NULL DEFAULT '',
			merk        VARCHAR(255) NOT NULL DEFAULT '',
			qty         INT NOT NULL DEFAULT 1,
			status      VARCHAR(50) NOT NULL DEFAULT 'active',
			rented_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
			returned_at DATETIME NULL,
			notes       TEXT DEFAULT '',
			UNIQUE KEY unique_rental_item (order_id, product_id)
		)
	`)
	if err != nil {
		log.Fatal("Gagal buat tabel rentals:", err)
	}

	_, err = database.DB.Exec(`
		CREATE TABLE IF NOT EXISTS user_vouchers (
			id INT AUTO_INCREMENT PRIMARY KEY,
			user_id VARCHAR(255) NOT NULL,
			code VARCHAR(100) NOT NULL,
			discount INT NOT NULL,
			is_used BOOLEAN NOT NULL DEFAULT FALSE,
			created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
		)
	`)

	if err != nil {
		log.Fatal("Gagal buat tabel user_vouchers:", err)
	}

	// =========================
	// HAPUS UNIQUE KEY user_id PADA user_vouchers (jika masih ada)
	// Agar satu user bisa punya banyak voucher reward
	// =========================
	var ukName string
	errUK := database.DB.QueryRow(`
		SELECT CONSTRAINT_NAME
		FROM INFORMATION_SCHEMA.TABLE_CONSTRAINTS
		WHERE TABLE_SCHEMA = DATABASE()
		AND TABLE_NAME = 'user_vouchers'
		AND CONSTRAINT_TYPE = 'UNIQUE'
		AND CONSTRAINT_NAME = 'unique_user_reward'
	`).Scan(&ukName)
	if errUK == nil {
		database.DB.Exec(`ALTER TABLE user_vouchers DROP INDEX unique_user_reward`)
	}

	// =========================
	// MIGRASI KOLOM name PADA TABEL vouchers
	// =========================
	var voucherNameCol string
	errVN := database.DB.QueryRow(`
		SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS
		WHERE TABLE_SCHEMA = DATABASE()
		AND TABLE_NAME = 'vouchers'
		AND COLUMN_NAME = 'name'
	`).Scan(&voucherNameCol)
	if errVN == sql.ErrNoRows {
		_, errVN = database.DB.Exec(`ALTER TABLE vouchers ADD COLUMN name VARCHAR(100) NOT NULL DEFAULT ''`)
		if errVN != nil {
			log.Fatal("Gagal menambahkan kolom name ke vouchers:", errVN)
		}
	}

	r := gin.Default()

	// GET PRODUCTS
	r.GET("/products", func(c *gin.Context) {

		rows, err := database.DB.Query(`
			SELECT p.id, p.category_id, p.merk, p.price, p.modal, p.stock, p.image,
			       p.supplier_id, IFNULL(s.name, '') AS supplier_name
			FROM products p
			LEFT JOIN suppliers s ON s.id = p.supplier_id
		`)

		if err != nil {
			c.JSON(500, gin.H{"error": err.Error()})
			return
		}

		defer rows.Close()

		var products []gin.H

		for rows.Next() {
			var id, categoryID, price, modal, stock, supplierID int
			var merk, image, supplierName string

			rows.Scan(&id, &categoryID, &merk, &price, &modal, &stock, &image, &supplierID, &supplierName)

			products = append(products, gin.H{
				"id":            id,
				"category_id":   categoryID,
				"merk":          merk,
				"price":         price,
				"modal":         modal,
				"stock":         stock,
				"image":         image,
				"supplier_id":   supplierID,
				"supplier_name": supplierName,
			})
		}

		c.JSON(http.StatusOK, products)

	})

	r.POST("/payment", handler.CreatePayment)
	r.GET("/payment-status/:orderId", handler.GetPaymentStatus)

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
			notes,
			status,
			payment_status,
			idempotency_key
		)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
		`,
			order.UserID,
			order.PaymentMethodID,
			order.PaymentChannel,
			order.MidtransOrderID,
			order.Total,
			order.VoucherCode,
			order.VoucherDiscount,
			order.Notes,
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
			SELECT
				o.id,
				o.total,
				o.status,
				o.created_at,
				COALESCE(NULLIF(o.customer_name,''), u.name, 'Pelanggan') AS customer_name,
				COALESCE(NULLIF(o.customer_phone,''), u.phone, '')         AS customer_phone,
				IFNULL(o.notes, '')                                        AS notes,
				o.is_offline
			FROM orders o
			LEFT JOIN users u ON u.firebase_uid = o.user_id
			ORDER BY o.id DESC
		`)

		if err != nil {
			c.JSON(500, gin.H{"error": err.Error()})
			return
		}

		defer rows.Close()

		var orders []gin.H

		for rows.Next() {
			var id, total, isOffline int
			var status, createdAt, customerName, customerPhone, notes string

			rows.Scan(&id, &total, &status, &createdAt, &customerName, &customerPhone, &notes, &isOffline)

			// Ambil items untuk order ini
			itemRows, _ := database.DB.Query(`
				SELECT p.merk, oi.qty, oi.subtotal, oi.service, p.price
				FROM order_items oi
				JOIN products p ON p.id = oi.product_id
				WHERE oi.order_id = ?
			`, id)

			var items []gin.H
			if itemRows != nil {
				for itemRows.Next() {
					var merk, service string
					var qty, subtotal, price int
					itemRows.Scan(&merk, &qty, &subtotal, &service, &price)
					items = append(items, gin.H{
						"product_name": merk,
						"merk":         merk,
						"qty":          qty,
						"subtotal":     subtotal,
						"service":      service,
						"price":        price,
					})
				}
				itemRows.Close()
			}
			if items == nil {
				items = []gin.H{}
			}

			orders = append(orders, gin.H{
				"id":             id,
				"total":          total,
				"status":         status,
				"created_at":     createdAt,
				"customer_name":  customerName,
				"customer_phone": customerPhone,
				"notes":          notes,
				"is_offline":     isOffline,
				"items":          items,
			})
		}

		if orders == nil {
			orders = []gin.H{}
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
		// AUTO-CATAT GALON SEWA (ONLINE ORDER SELESAI)
		// =========================
		if body.Status == "Selesai" {
			sewaRows, sewaErr := database.DB.Query(`
				SELECT oi.product_id, oi.qty, p.merk, o.user_id
				FROM order_items oi
				JOIN products p ON p.id = oi.product_id
				JOIN orders o ON o.id = oi.order_id
				WHERE oi.order_id = ? AND oi.service = 'Sewa'
			`, id)
			if sewaErr == nil {
				for sewaRows.Next() {
					var pID, qty int
					var merk, uID string
					sewaRows.Scan(&pID, &qty, &merk, &uID)
					database.DB.Exec(`
						INSERT IGNORE INTO rentals (order_id, product_id, user_id, merk, qty, status)
						VALUES (?, ?, ?, ?, ?, 'active')
					`, id, pID, uID, merk, qty)
				}
				sewaRows.Close()
			}
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

			if body.Status == "Selesai" {

				// =========================
				// AMBIL USER ID
				// =========================
				var userID string

				err := database.DB.QueryRow(`
		SELECT user_id
		FROM orders
		WHERE id = ?
	`, id).Scan(&userID)

				if err == nil {

					// =========================
					// HITUNG ORDER SELESAI
					// =========================
					var selesaiCount int

					err = database.DB.QueryRow(`
			SELECT COUNT(*)
			FROM orders
			WHERE user_id = ?
			AND status = 'Selesai'
		`, userID).Scan(&selesaiCount)

					if err == nil {

						// =========================
						// HITUNG VOUCHER REWARD
						// =========================
						var rewardCount int

						err = database.DB.QueryRow(`
				SELECT COUNT(*)
				FROM user_vouchers
				WHERE user_id = ?
			`, userID).Scan(&rewardCount)

						if err == nil {
							// Ambil pengaturan reward dari tabel
							var rewardMultiplier, rewardDiscount int
							if rErr := database.DB.QueryRow(`SELECT multiplier, discount FROM reward_settings WHERE id = 1`).Scan(&rewardMultiplier, &rewardDiscount); rErr != nil {
								rewardMultiplier = 5
								rewardDiscount = 2000
							}

							expectedReward := selesaiCount / rewardMultiplier

							if rewardCount < expectedReward {

								code := generateVoucherCode()

								_, err = database.DB.Exec(`
						INSERT INTO user_vouchers
						(user_id, code, discount, is_used)
						VALUES (?, ?, ?, false)
					`,
									userID,
									code,
									rewardDiscount,
								)

								if err == nil {

									log.Println(
										"VOUCHER REWARD DIBUAT:",
										code,
									)
								}
							}
						}
					}
				}
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

	// =========================
	// LIST SEMUA USER (KELOLA ROLE)
	// =========================
	r.GET("/users", func(c *gin.Context) {

		rows, err := database.DB.Query(`
			SELECT firebase_uid, email, name, phone, role
			FROM users
			ORDER BY
				FIELD(role, 'admin', 'kasir', 'kurir', 'customer'),
				name ASC
		`)

		if err != nil {
			c.JSON(500, gin.H{"error": err.Error()})
			return
		}

		defer rows.Close()

		var users []gin.H

		for rows.Next() {
			var uid, email, name, phone, role string

			rows.Scan(&uid, &email, &name, &phone, &role)

			users = append(users, gin.H{
				"firebase_uid": uid,
				"email":        email,
				"name":         name,
				"phone":        phone,
				"role":         role,
			})
		}

		c.JSON(200, users)
	})

	// =========================
	// UPDATE ROLE USER (KELOLA ROLE)
	// =========================
	r.PUT("/users/:uid/role", func(c *gin.Context) {

		uid := c.Param("uid")

		var body struct {
			Role string `json:"role"`
		}

		if err := c.ShouldBindJSON(&body); err != nil {
			c.JSON(400, gin.H{"error": err.Error()})
			return
		}

		allowedRoles := map[string]bool{
			"customer": true,
			"kurir":    true,
			"kasir":    true,
			"admin":    true,
		}

		if !allowedRoles[body.Role] {
			c.JSON(400, gin.H{"error": "Role tidak valid"})
			return
		}

		result, err := database.DB.Exec(`
			UPDATE users
			SET role = ?
			WHERE firebase_uid = ?
		`, body.Role, uid)

		if err != nil {
			c.JSON(500, gin.H{"error": err.Error()})
			return
		}

		affected, _ := result.RowsAffected()
		if affected == 0 {
			c.JSON(404, gin.H{"error": "User tidak ditemukan"})
			return
		}

		c.JSON(200, gin.H{"message": "Role berhasil diperbarui"})
	})

	// =========================
	// TRANSAKSI KASIR (OFFLINE / TUNAI)
	// =========================
	r.POST("/kasir/orders", func(c *gin.Context) {

		var body struct {
			KasirUID      string      `json:"kasir_uid"`
			CustomerName  string      `json:"customer_name"`
			CustomerPhone string      `json:"customer_phone"`
			Total         int         `json:"total"`
			Items         []OrderItem `json:"items"`
		}

		if err := c.ShouldBindJSON(&body); err != nil {
			c.JSON(400, gin.H{"error": err.Error()})
			return
		}

		if body.KasirUID == "" {
			c.JSON(400, gin.H{"error": "Kasir tidak dikenali"})
			return
		}

		if len(body.Items) == 0 {
			c.JSON(400, gin.H{"error": "Keranjang masih kosong"})
			return
		}

		tx, err := database.DB.Begin()
		if err != nil {
			c.JSON(500, gin.H{"error": "Gagal begin transaction"})
			return
		}

		// Kunci idempotency unik agar tidak bentrok dengan order online
		keyBuf := make([]byte, 8)
		rand.Read(keyBuf)
		offlineKey := "KASIR-" + hex.EncodeToString(keyBuf)

		// INSERT ORDER (langsung Selesai & lunas tunai)
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
				idempotency_key,
				customer_name,
				customer_phone,
				is_offline
			)
			VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
		`,
			body.KasirUID,
			0,
			"cash",
			offlineKey,
			body.Total,
			"",
			0,
			"Selesai",
			"paid",
			offlineKey,
			body.CustomerName,
			body.CustomerPhone,
			1,
		)

		if err != nil {
			tx.Rollback()
			log.Println("INSERT KASIR ORDER ERROR:", err)
			c.JSON(500, gin.H{"error": err.Error()})
			return
		}

		orderID, _ := result.LastInsertId()

		// INSERT ITEMS + KURANGI STOK LANGSUNG
		for _, item := range body.Items {

			_, err = tx.Exec(`
				INSERT INTO order_items
				(order_id, product_id, qty, subtotal, service)
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
				c.JSON(500, gin.H{"error": err.Error()})
				return
			}

			// Isi Ulang tidak mengurangi stok galon
			if item.Service != "Isi Ulang" {

				var stock int
				err = tx.QueryRow(`
					SELECT stock FROM products WHERE id = ? FOR UPDATE
				`, item.ProductID).Scan(&stock)

				if err != nil {
					tx.Rollback()
					c.JSON(500, gin.H{"error": err.Error()})
					return
				}

				if stock < item.Qty {
					tx.Rollback()
					c.JSON(400, gin.H{"error": "Stok tidak cukup"})
					return
				}

				_, err = tx.Exec(`
					UPDATE products
					SET stock = stock - ?
					WHERE id = ?
				`, item.Qty, item.ProductID)

				if err != nil {
					tx.Rollback()
					c.JSON(500, gin.H{"error": err.Error()})
					return
				}
			}
		}

		if err = tx.Commit(); err != nil {
			c.JSON(500, gin.H{"error": "Gagal commit transaction"})
			return
		}

		// =========================
		// AUTO-CATAT GALON SEWA (KASIR OFFLINE)
		// =========================
		for _, item := range body.Items {
			if item.Service == "Sewa" {
				var merk string
				database.DB.QueryRow(`SELECT merk FROM products WHERE id = ?`, item.ProductID).Scan(&merk)
				database.DB.Exec(`
					INSERT IGNORE INTO rentals (order_id, product_id, user_id, merk, qty, status)
					VALUES (?, ?, ?, ?, ?, 'active')
				`, orderID, item.ProductID, body.KasirUID, merk, item.Qty)
			}
		}

		c.JSON(200, gin.H{
			"message":  "Transaksi tunai berhasil",
			"order_id": orderID,
		})
	})

	// =========================
	// RIWAYAT TRANSAKSI KASIR + RINGKASAN HARI INI
	// =========================
	r.GET("/kasir/transactions/:uid", func(c *gin.Context) {

		uid := c.Param("uid")

		var todayTotal int
		var todayCount int

		database.DB.QueryRow(`
			SELECT IFNULL(SUM(total), 0), COUNT(*)
			FROM orders
			WHERE is_offline = 1
			AND user_id = ?
			AND DATE(created_at) = CURDATE()
		`, uid).Scan(&todayTotal, &todayCount)

		rows, err := database.DB.Query(`
			SELECT id, total, customer_name, customer_phone, status, created_at
			FROM orders
			WHERE is_offline = 1
			AND user_id = ?
			ORDER BY id DESC
			LIMIT 50
		`, uid)

		if err != nil {
			c.JSON(500, gin.H{"error": err.Error()})
			return
		}

		defer rows.Close()

		var transactions []gin.H

		for rows.Next() {
			var id, total int
			var customerName, customerPhone, status, createdAt string

			rows.Scan(&id, &total, &customerName, &customerPhone, &status, &createdAt)

			transactions = append(transactions, gin.H{
				"id":             id,
				"total":          total,
				"customer_name":  customerName,
				"customer_phone": customerPhone,
				"status":         status,
				"created_at":     createdAt,
			})
		}

		c.JSON(200, gin.H{
			"today_total":  todayTotal,
			"today_count":  todayCount,
			"transactions": transactions,
		})
	})

	// CREATE PRODUCT
	r.POST("/products", func(c *gin.Context) {

		var product Product

		if err := c.ShouldBindJSON(&product); err != nil {
			c.JSON(400, gin.H{"error": err.Error()})
			return
		}

		_, err := database.DB.Exec(`
		INSERT INTO products
		(category_id, merk, price, modal, stock, image, supplier_id)
		VALUES (?, ?, ?, ?, ?, ?, ?)
	`,
			product.CategoryID,
			product.Merk,
			product.Price,
			product.Modal,
			product.Stock,
			product.Image,
			product.SupplierID,
		)

		if err != nil {
			c.JSON(500, gin.H{"error": err.Error()})
			return
		}

		c.JSON(200, gin.H{"message": "Produk berhasil ditambahkan"})
	})

	// UPDATE PRODUCT
	r.PUT("/products/:id", func(c *gin.Context) {

		id := c.Param("id")

		var product Product

		if err := c.ShouldBindJSON(&product); err != nil {
			c.JSON(400, gin.H{"error": err.Error()})
			return
		}

		_, err := database.DB.Exec(`
		UPDATE products
		SET
			category_id = ?,
			merk = ?,
			price = ?,
			modal = ?,
			stock = ?,
			image = ?,
			supplier_id = ?
		WHERE id = ?
	`,
			product.CategoryID,
			product.Merk,
			product.Price,
			product.Modal,
			product.Stock,
			product.Image,
			product.SupplierID,
			id,
		)

		if err != nil {
			c.JSON(500, gin.H{"error": err.Error()})
			return
		}

		c.JSON(200, gin.H{"message": "Produk berhasil diupdate"})
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

		var monthlyProfit int
		var pendingOrders int

		database.DB.QueryRow(`
		SELECT IFNULL(SUM(total), 0)
		FROM orders
		WHERE status != 'Dibatalkan'
		AND MONTH(created_at) = MONTH(CURDATE())
		AND YEAR(created_at) = YEAR(CURDATE())
	`).Scan(&monthlyProfit)

		database.DB.QueryRow(`
		SELECT COUNT(*)
		FROM orders
		WHERE status = 'Diproses'
	`).Scan(&pendingOrders)

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
			"monthly_profit":  monthlyProfit,
			"pending_orders":  pendingOrders,
			"best_products":   bestProducts,
		})
	})

	// GET ALL VOUCHERS
	r.GET("/vouchers", func(c *gin.Context) {

		rows, err := database.DB.Query(`
			SELECT id, IFNULL(name,''), code, discount, is_active
			FROM vouchers
			ORDER BY id DESC
		`)

		if err != nil {
			c.JSON(500, gin.H{"error": err.Error()})
			return
		}

		defer rows.Close()

		var vouchers []Voucher
		for rows.Next() {
			var voucher Voucher
			rows.Scan(&voucher.ID, &voucher.Name, &voucher.Code, &voucher.Discount, &voucher.IsActive)
			vouchers = append(vouchers, voucher)
		}

		if vouchers == nil {
			vouchers = []Voucher{}
		}
		c.JSON(200, vouchers)
	})

	// CREATE VOUCHER
	r.POST("/vouchers", func(c *gin.Context) {

		var voucher Voucher

		if err := c.ShouldBindJSON(&voucher); err != nil {
			c.JSON(400, gin.H{"error": err.Error()})
			return
		}

		if voucher.Discount <= 0 {
			c.JSON(400, gin.H{"error": "Nominal diskon harus lebih dari 0"})
			return
		}

		if voucher.Code == "" {
			voucher.Code = generateVoucherCode()
		}

		_, err := database.DB.Exec(`
			INSERT INTO vouchers (name, code, discount, is_active)
			VALUES (?, ?, ?, true)
		`, voucher.Name, voucher.Code, voucher.Discount)

		if err != nil {

			c.JSON(500, gin.H{
				"error": err.Error(),
			})

			return
		}

		c.JSON(200, gin.H{
			"message": "Voucher berhasil dibuat",
			"name":    voucher.Name,
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
			COALESCE(NULLIF(o.customer_name, ''), u.name, 'Pelanggan Offline') AS name,
			o.total,
			o.status,
			o.created_at,
			o.is_offline
		FROM orders o
		LEFT JOIN users u
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
			var isOffline int

			rows.Scan(
				&id,
				&name,
				&total,
				&status,
				&createdAt,
				&isOffline,
			)

			reports = append(reports, gin.H{
				"id":         id,
				"name":       name,
				"total":      total,
				"status":     status,
				"created_at": createdAt,
				"is_offline": isOffline,
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

	// =========================
	// GET DAFTAR SEWA GALON
	// =========================
	r.GET("/rentals", func(c *gin.Context) {
		rows, err := database.DB.Query(`
			SELECT
				r.id, r.order_id, r.product_id, r.merk, r.qty,
				r.status, r.rented_at,
				COALESCE(r.returned_at, '') AS returned_at,
				COALESCE(r.notes, '')       AS notes,
				o.is_offline,
				CASE WHEN o.is_offline = 1
					THEN IFNULL(NULLIF(o.customer_name,''), 'Pelanggan Umum')
					ELSE IFNULL(u.name, 'Pelanggan')
				END AS customer_name,
				CASE WHEN o.is_offline = 1
					THEN IFNULL(o.customer_phone, '')
					ELSE IFNULL(u.phone, '')
				END AS customer_phone
			FROM rentals r
			JOIN orders o ON o.id = r.order_id
			LEFT JOIN users u ON u.firebase_uid = r.user_id
			ORDER BY r.rented_at DESC
		`)
		if err != nil {
			c.JSON(500, gin.H{"error": err.Error()})
			return
		}
		defer rows.Close()

		var rentals []gin.H
		for rows.Next() {
			var id, orderID, productID, qty, isOffline int
			var merk, status, rentedAt, returnedAt, notes, customerName, customerPhone string
			rows.Scan(&id, &orderID, &productID, &merk, &qty, &status, &rentedAt, &returnedAt, &notes, &isOffline, &customerName, &customerPhone)
			rentals = append(rentals, gin.H{
				"id":             id,
				"order_id":       orderID,
				"product_id":     productID,
				"merk":           merk,
				"qty":            qty,
				"status":         status,
				"rented_at":      rentedAt,
				"returned_at":    returnedAt,
				"notes":          notes,
				"customer_name":  customerName,
				"customer_phone": customerPhone,
			})
		}

		if rentals == nil {
			rentals = []gin.H{}
		}
		c.JSON(200, rentals)
	})

	// =========================
	// TANDAI GALON DIKEMBALIKAN
	// =========================
	r.POST("/rentals/:id/return", func(c *gin.Context) {
		id := c.Param("id")
		result, err := database.DB.Exec(`
			UPDATE rentals
			SET status = 'returned', returned_at = NOW()
			WHERE id = ? AND status = 'active'
		`, id)
		if err != nil {
			c.JSON(500, gin.H{"error": err.Error()})
			return
		}
		affected, _ := result.RowsAffected()
		if affected == 0 {
			c.JSON(400, gin.H{"error": "Data sewa tidak ditemukan atau sudah tidak aktif"})
			return
		}
		c.JSON(200, gin.H{"message": "Galon berhasil dicatat dikembalikan"})
	})

	// =========================
	// KONVERSI SEWA → BELI BARU (GALON RUSAK)
	// =========================
	r.POST("/rentals/:id/convert-damage", func(c *gin.Context) {
		id := c.Param("id")

		var rentalOrderID, rentalProductID, rentalQty int
		var rentalUserID, rentalMerk string

		err := database.DB.QueryRow(`
			SELECT order_id, product_id, user_id, merk, qty
			FROM rentals
			WHERE id = ? AND status = 'active'
		`, id).Scan(&rentalOrderID, &rentalProductID, &rentalUserID, &rentalMerk, &rentalQty)
		if err != nil {
			c.JSON(404, gin.H{"error": "Data sewa tidak ditemukan atau sudah tidak aktif"})
			return
		}

		var productPrice int
		database.DB.QueryRow(`SELECT price FROM products WHERE id = ?`, rentalProductID).Scan(&productPrice)
		total := productPrice * rentalQty

		// Ambil info pelanggan dari pesanan asli
		var oriCustomerName, oriCustomerPhone string
		var isOffline int
		database.DB.QueryRow(`
			SELECT IFNULL(customer_name,''), IFNULL(customer_phone,''), is_offline
			FROM orders WHERE id = ?
		`, rentalOrderID).Scan(&oriCustomerName, &oriCustomerPhone, &isOffline)

		if isOffline == 0 {
			database.DB.QueryRow(`SELECT IFNULL(name,''), IFNULL(phone,'') FROM users WHERE firebase_uid = ?`, rentalUserID).Scan(&oriCustomerName, &oriCustomerPhone)
		}

		tx, err := database.DB.Begin()
		if err != nil {
			c.JSON(500, gin.H{"error": "Gagal begin transaction"})
			return
		}

		keyBuf := make([]byte, 8)
		rand.Read(keyBuf)
		damageKey := "DAMAGE-" + hex.EncodeToString(keyBuf)

		// INSERT ORDER GANTI GALON RUSAK
		result, err := tx.Exec(`
			INSERT INTO orders
			(user_id, payment_method_id, payment_channel, midtrans_order_id, total,
			 voucher_code, voucher_discount, status, payment_status, idempotency_key,
			 customer_name, customer_phone, is_offline)
			VALUES (?, 0, 'damage-convert', ?, ?, '', 0, 'Selesai', 'pending', ?, ?, ?, 1)
		`, rentalUserID, damageKey, total, damageKey, oriCustomerName, oriCustomerPhone)
		if err != nil {
			tx.Rollback()
			c.JSON(500, gin.H{"error": err.Error()})
			return
		}

		newOrderID, _ := result.LastInsertId()

		_, err = tx.Exec(`
			INSERT INTO order_items (order_id, product_id, qty, subtotal, service)
			VALUES (?, ?, ?, ?, 'Beli Baru')
		`, newOrderID, rentalProductID, rentalQty, total)
		if err != nil {
			tx.Rollback()
			c.JSON(500, gin.H{"error": err.Error()})
			return
		}

		_, err = tx.Exec(`UPDATE products SET stock = stock - ? WHERE id = ?`, rentalQty, rentalProductID)
		if err != nil {
			tx.Rollback()
			c.JSON(500, gin.H{"error": err.Error()})
			return
		}

		_, err = tx.Exec(`
			UPDATE rentals
			SET status = 'damaged', returned_at = NOW(),
			    notes = CONCAT('Galon rusak — dikonversi ke Beli Baru. Tagihan: Rp ', ?)
			WHERE id = ?
		`, total, id)
		if err != nil {
			tx.Rollback()
			c.JSON(500, gin.H{"error": err.Error()})
			return
		}

		if err = tx.Commit(); err != nil {
			c.JSON(500, gin.H{"error": "Gagal commit"})
			return
		}

		c.JSON(200, gin.H{
			"message":        "Galon rusak dicatat, pesanan Beli Baru dibuat",
			"new_order_id":   newOrderID,
			"total_tagihan":  total,
			"merk":           rentalMerk,
			"customer":       oriCustomerName,
		})
	})

	// =========================
	// GET SEMUA SUPPLIER
	// =========================
	r.GET("/suppliers", func(c *gin.Context) {
		rows, err := database.DB.Query(`
			SELECT id, name, IFNULL(phone,''), IFNULL(address,'')
			FROM suppliers ORDER BY name ASC`)
		if err != nil {
			c.JSON(500, gin.H{"error": err.Error()})
			return
		}
		defer rows.Close()

		var suppliers []Supplier
		for rows.Next() {
			var s Supplier
			rows.Scan(&s.ID, &s.Name, &s.Phone, &s.Address)
			suppliers = append(suppliers, s)
		}
		if suppliers == nil {
			suppliers = []Supplier{}
		}
		c.JSON(200, suppliers)
	})

	// =========================
	// TAMBAH SUPPLIER
	// =========================
	r.POST("/suppliers", func(c *gin.Context) {
		var body struct {
			Name    string `json:"name"`
			Phone   string `json:"phone"`
			Address string `json:"address"`
		}
		if err := c.ShouldBindJSON(&body); err != nil || body.Name == "" {
			c.JSON(400, gin.H{"error": "Nama supplier wajib diisi"})
			return
		}

		result, err := database.DB.Exec(
			`INSERT INTO suppliers (name, phone, address) VALUES (?, ?, ?)`,
			body.Name, body.Phone, body.Address,
		)
		if err != nil {
			c.JSON(500, gin.H{"error": err.Error()})
			return
		}

		id, _ := result.LastInsertId()
		c.JSON(200, gin.H{"id": id, "name": body.Name, "phone": body.Phone, "address": body.Address})
	})

	// =========================
	// HAPUS SUPPLIER
	// =========================
	r.DELETE("/suppliers/:id", func(c *gin.Context) {
		id := c.Param("id")
		_, err := database.DB.Exec(`DELETE FROM suppliers WHERE id = ?`, id)
		if err != nil {
			c.JSON(500, gin.H{"error": err.Error()})
			return
		}
		c.JSON(200, gin.H{"message": "Supplier berhasil dihapus"})
	})

	// =========================
	// UPDATE VOUCHER (edit nama/kode/diskon, atau toggle is_active)
	// =========================
	r.PUT("/vouchers/:id", func(c *gin.Context) {
		id := c.Param("id")

		var body struct {
			Name     string `json:"name"`
			Code     string `json:"code"`
			Discount int    `json:"discount"`
			IsActive *bool  `json:"is_active"`
		}

		if err := c.ShouldBindJSON(&body); err != nil {
			c.JSON(400, gin.H{"error": err.Error()})
			return
		}

		if body.IsActive != nil {
			// Toggle aktif/nonaktif
			_, err := database.DB.Exec(`UPDATE vouchers SET is_active = ? WHERE id = ?`, *body.IsActive, id)
			if err != nil {
				c.JSON(500, gin.H{"error": err.Error()})
				return
			}
		} else {
			// Edit detail voucher
			if body.Discount <= 0 {
				c.JSON(400, gin.H{"error": "Nominal diskon harus lebih dari 0"})
				return
			}
			_, err := database.DB.Exec(
				`UPDATE vouchers SET name = ?, code = ?, discount = ? WHERE id = ?`,
				body.Name, body.Code, body.Discount, id,
			)
			if err != nil {
				c.JSON(500, gin.H{"error": err.Error()})
				return
			}
		}

		c.JSON(200, gin.H{"message": "Voucher berhasil diupdate"})
	})

	// =========================
	// GET PENERIMA VOUCHER
	// =========================
	r.GET("/vouchers/:id/recipients", func(c *gin.Context) {
		id := c.Param("id")

		var voucherCode string
		err := database.DB.QueryRow(`SELECT code FROM vouchers WHERE id = ?`, id).Scan(&voucherCode)
		if err != nil {
			c.JSON(404, gin.H{"error": "Voucher tidak ditemukan"})
			return
		}

		rows, err := database.DB.Query(`
			SELECT IFNULL(u.name,''), u.email
			FROM user_vouchers uv
			JOIN users u ON u.firebase_uid = uv.user_id
			WHERE uv.code = ?
			ORDER BY uv.created_at DESC
		`, voucherCode)
		if err != nil {
			c.JSON(500, gin.H{"error": err.Error()})
			return
		}
		defer rows.Close()

		var recipients []gin.H
		for rows.Next() {
			var name, email string
			rows.Scan(&name, &email)
			recipients = append(recipients, gin.H{"name": name, "email": email})
		}
		if recipients == nil {
			recipients = []gin.H{}
		}
		c.JSON(200, recipients)
	})

	// =========================
	// GET PENGATURAN REWARD OTOMATIS
	// =========================
	r.GET("/reward-settings", func(c *gin.Context) {
		var multiplier, discount int
		err := database.DB.QueryRow(`SELECT multiplier, discount FROM reward_settings WHERE id = 1`).Scan(&multiplier, &discount)
		if err != nil {
			c.JSON(200, gin.H{"multiplier": 5, "discount": 2000})
			return
		}
		c.JSON(200, gin.H{"multiplier": multiplier, "discount": discount})
	})

	// =========================
	// UPDATE PENGATURAN REWARD OTOMATIS
	// =========================
	r.PUT("/reward-settings", func(c *gin.Context) {
		var body RewardSettings
		if err := c.ShouldBindJSON(&body); err != nil {
			c.JSON(400, gin.H{"error": err.Error()})
			return
		}
		if body.Multiplier <= 0 || body.Discount <= 0 {
			c.JSON(400, gin.H{"error": "Nilai harus lebih dari 0"})
			return
		}
		_, err := database.DB.Exec(
			`UPDATE reward_settings SET multiplier = ?, discount = ? WHERE id = 1`,
			body.Multiplier, body.Discount,
		)
		if err != nil {
			c.JSON(500, gin.H{"error": err.Error()})
			return
		}
		c.JSON(200, gin.H{"message": "Pengaturan reward berhasil disimpan", "multiplier": body.Multiplier, "discount": body.Discount})
	})

	r.Run(":8080")
}
