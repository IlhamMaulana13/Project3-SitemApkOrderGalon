package main

import (
	"backend-galon/database"
	"net/http"

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
	ProductID int `json:"product_id"`
	Qty       int `json:"qty"`
	Subtotal  int `json:"subtotal"`
}

type Order struct {
	UserID          string      `json:"user_id"`
	PaymentMethodID int         `json:"payment_method_id"`
	Total           int         `json:"total"`
	Items           []OrderItem `json:"items"`
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

func main() {

	database.ConnectDB()

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

	// POST ORDER
	r.POST("/orders", func(c *gin.Context) {

		var order Order

		if err := c.ShouldBindJSON(&order); err != nil {
			c.JSON(400, gin.H{
				"error": err.Error(),
			})
			return
		}

		result, err := database.DB.Exec(`
			INSERT INTO orders
			(user_id, payment_method_id, total, status)
			VALUES (?, ?, ?, ?)
		`,
			order.UserID,
			order.PaymentMethodID,
			order.Total,
			"Diproses",
		)

		if err != nil {
			c.JSON(500, gin.H{
				"error": err.Error(),
			})
			return
		}

		orderID, _ := result.LastInsertId()

		for _, item := range order.Items {

			// CEK STOCK
			var stock int

			err := database.DB.QueryRow(`
		SELECT stock
		FROM products
		WHERE id = ?
	`,
				item.ProductID,
			).Scan(&stock)

			if err != nil {

				c.JSON(500, gin.H{
					"error": err.Error(),
				})

				return
			}

			// VALIDASI STOCK
			if stock < item.Qty {

				c.JSON(400, gin.H{
					"error": "Stock tidak cukup",
				})

				return
			}

			// INSERT ORDER ITEM
			_, err = database.DB.Exec(`
		INSERT INTO order_items
		(order_id, product_id, qty, subtotal)
		VALUES (?, ?, ?, ?)
	`,
				orderID,
				item.ProductID,
				item.Qty,
				item.Subtotal,
			)

			if err != nil {

				c.JSON(500, gin.H{
					"error": err.Error(),
				})

				return
			}

			// KURANGI STOCK
			_, err = database.DB.Exec(`
					UPDATE products
					SET stock = stock - ?
					WHERE id = ?
				`,
				item.Qty,
				item.ProductID,
			)

			if err != nil {

				c.JSON(500, gin.H{
					"error": err.Error(),
				})

				return
			}
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

		c.JSON(200, gin.H{
			"message": "Status berhasil diupdate",
		})
	})

	// CREATE USER
	r.POST("/users", func(c *gin.Context) {

		var body struct {
			FirebaseUID string `json:"firebase_uid"`
			Email       string `json:"email"`
		}

		if err := c.ShouldBindJSON(&body); err != nil {

			c.JSON(400, gin.H{
				"error": err.Error(),
			})

			return
		}

		// cek user sudah ada atau belum
		var count int

		database.DB.QueryRow(`
		SELECT COUNT(*)
		FROM users
		WHERE firebase_uid = ?
	`, body.FirebaseUID).Scan(&count)

		// kalau belum ada → insert
		if count == 0 {

			_, err := database.DB.Exec(`
			INSERT INTO users
			(firebase_uid, email, role)
			VALUES (?, ?, ?)
		`,
				body.FirebaseUID,
				body.Email,
				"customer",
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

	// GET ORDER KHUSUS KURIR
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
		JOIN users u
		ON u.firebase_uid = o.user_id
		WHERE o.status IN ('Siap Dikirim', 'Dikirim')
		ORDER BY o.id DESC
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

	r.Run(":8080")
}
