package handler

import (
	"log"
	"net/http"

	"backend-galon/database"
	"backend-galon/service"

	"github.com/gin-gonic/gin"
)

type PaymentRequest struct {
	OrderID       string `json:"order_id"`
	Total         int64  `json:"total"`
	CustomerName  string `json:"customer_name"`
	CustomerEmail string `json:"customer_email"`
	CustomerPhone string `json:"customer_phone"`
}

func CreatePayment(c *gin.Context) {
	var req PaymentRequest

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Request tidak valid"})
		return
	}

	if req.OrderID == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "order_id wajib diisi"})
		return
	}

	if req.Total <= 0 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Total harus lebih dari 0"})
		return
	}

	log.Printf("CREATE PAYMENT: %s | Rp %d | %s", req.OrderID, req.Total, req.CustomerName)

	resp, err := service.CreatePayment(service.PaymentInput{
		OrderID:       req.OrderID,
		Amount:        req.Total,
		CustomerName:  req.CustomerName,
		CustomerEmail: req.CustomerEmail,
		CustomerPhone: req.CustomerPhone,
	})

	if err != nil {
		log.Println("MIDTRANS FAILED:", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Gagal membuat transaksi pembayaran"})
		return
	}

	if resp == nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Respons Midtrans kosong"})
		return
	}

	log.Println("MIDTRANS SUCCESS:", resp.RedirectURL)

	// Simpan payment_url ke orders
	_, dbErr := database.DB.Exec(
		`UPDATE orders SET payment_url = ? WHERE midtrans_order_id = ?`,
		resp.RedirectURL,
		req.OrderID,
	)
	if dbErr != nil {
		log.Println("UPDATE PAYMENT URL ERROR:", dbErr)
	}

	c.JSON(http.StatusOK, gin.H{
		"success":      true,
		"token":        resp.Token,
		"redirect_url": resp.RedirectURL,
	})
}

func GetPaymentStatus(c *gin.Context) {
	orderId := c.Param("orderId")

	var paymentStatus string

	err := database.DB.QueryRow(
		`SELECT payment_status FROM orders WHERE midtrans_order_id = ?`,
		orderId,
	).Scan(&paymentStatus)

	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Order tidak ditemukan"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"success": true,
		"status":  paymentStatus,
	})
}
