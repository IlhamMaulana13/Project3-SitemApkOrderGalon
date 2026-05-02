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

			_, err := database.DB.Exec(`
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

	r.Run(":8080")
}
