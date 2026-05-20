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
			"message": "Invalid request body",
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

		// JANGAN PAKAI err.Error()
		// karena SDK Midtrans bisa panic

		c.JSON(http.StatusInternalServerError, gin.H{
			"success": false,
			"message": "Gagal membuat transaksi",
		})

		return
	}

	log.Println("SEND TO FLUTTER:", resp.RedirectURL)

	c.JSON(http.StatusOK, gin.H{
		"success":      true,
		"message":      "Payment berhasil dibuat",
		"token":        resp.Token,
		"redirect_url": resp.RedirectURL,
	})
}
