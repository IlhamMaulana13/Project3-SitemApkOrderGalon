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

func main() {

	// CONNECT DB
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

		// INSERT ORDER
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

		// INSERT ORDER ITEMS
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

	r.Run(":8080")
}
