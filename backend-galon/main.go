package main

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

type Product struct {
	ID    int    `json:"id"`
	Name  string `json:"name"`
	Price int    `json:"price"`
}

var products = []Product{
	{ID: 1, Name: "Galon Isi Ulang", Price: 15000},
	{ID: 2, Name: "Galon Baru", Price: 50000},
}

func main() {
	r := gin.Default()

	// GET PRODUCTS
	r.GET("/products", func(c *gin.Context) {
		c.JSON(http.StatusOK, products)
	})

	// POST ORDER
	r.POST("/orders", func(c *gin.Context) {
		var order map[string]interface{}

		if err := c.ShouldBindJSON(&order); err != nil {
			c.JSON(400, gin.H{"error": err.Error()})
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
