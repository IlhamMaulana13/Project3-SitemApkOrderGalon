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

		var order map[string]interface{}

		if err := c.ShouldBindJSON(&order); err != nil {
			c.JSON(400, gin.H{
				"error": err.Error(),
			})
			return
		}

		order["status"] = "Diproses"

		c.JSON(200, gin.H{
			"message": "Order berhasil",
			"data":    order,
		})
	})

	r.Run(":8080")
}