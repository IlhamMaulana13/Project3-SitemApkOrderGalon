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

	// VALIDASI JSON
	if err := c.ShouldBindJSON(&req); err != nil {

		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"message": "Invalid request body",
		})

		return
	}

	// VALIDASI ORDER ID
	if req.OrderID == "" {

		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"message": "order_id wajib diisi",
		})

		return
	}

	// VALIDASI TOTAL
	if req.Total <= 0 {

		c.JSON(http.StatusBadRequest, gin.H{
			"success": false,
			"message": "total harus lebih dari 0",
		})

		return
	}

	log.Println("CREATE PAYMENT:", req.OrderID, req.Total)

	// CREATE MIDTRANS
	resp, err := service.CreatePayment(
		req.OrderID,
		req.Total,
	)

	log.Println("RESP:", resp)
	log.Println("ERR:", err)

	// HANDLE ERROR
	if err != nil {

		log.Println("MIDTRANS ERROR:", err)

		c.JSON(http.StatusInternalServerError, gin.H{
			"success": false,
			"message": "Gagal membuat transaksi",
		})

		return
	}

	// HANDLE NIL RESPONSE
	if resp == nil {

		c.JSON(http.StatusInternalServerError, gin.H{
			"success": false,
			"message": "response midtrans kosong",
		})

		return
	}

	log.Println("MIDTRANS SUCCESS:", resp.RedirectURL)

	// RESPONSE KE FLUTTER
	c.JSON(http.StatusOK, gin.H{
		"success":      true,
		"message":      "Payment berhasil dibuat",
		"token":        resp.Token,
		"redirect_url": resp.RedirectURL,
	})

	log.Println("SEND TO FLUTTER:", resp.RedirectURL)
}