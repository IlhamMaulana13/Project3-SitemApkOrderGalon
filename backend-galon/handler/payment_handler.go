package handler

import (
	"log"
	"net/http"

	"backend-galon/service"

	"github.com/gin-gonic/gin"
)

type PaymentRequest struct {
	OrderID string `json:"order_id"`
	Total   int64  `json:"total"`
}

func CreatePayment(c *gin.Context) {

	var req PaymentRequest

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"message": "Invalid request",
			"error":   err.Error(),
		})
		return
	}

	if req.OrderID == "" {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"message": "order_id wajib diisi",
		})
		return
	}

	if req.Total <= 0 {
		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"message": "total harus lebih dari 0",
		})
		return
	}

	log.Println("CREATE PAYMENT:", req.OrderID, req.Total)

	resp, err := service.CreatePayment(
		req.OrderID,
		req.Total,
	)

	if err != nil {

		log.Println("MIDTRANS ERROR:", err)

		c.JSON(http.StatusInternalServerError, gin.H{
			"success": false,
			"message": "Gagal membuat payment",
			"error":   err.Error(),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success":      true,
		"token":        resp.Token,
		"redirect_url": resp.RedirectURL,
	})
}
