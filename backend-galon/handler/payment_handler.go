package handler

import (
	"log"
	"net/http"

	"backend-galon/database"
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

	_, err = database.DB.Exec(`
	UPDATE orders
	SET payment_url=?
	WHERE midtrans_order_id=?
`,
		resp.RedirectURL,
		req.OrderID,
	)

	if err != nil {

		log.Println("UPDATE PAYMENT URL ERROR:", err)

		c.JSON(500, gin.H{
			"success": false,
			"message": "Gagal simpan payment url",
		})

		return
	}

	log.Println("RESP:", resp)
	log.Println("ERR:", err)

	if err != nil {

		log.Println("MIDTRANS FAILED")

		c.JSON(http.StatusInternalServerError, gin.H{
			"success": false,
			"message": "Gagal membuat transaksi",
		})

		return
	}

	if resp == nil {

		c.JSON(http.StatusInternalServerError, gin.H{
			"success": false,
			"message": "Response Midtrans kosong",
		})

		return
	}

	log.Println("MIDTRANS SUCCESS:", resp.RedirectURL)

	c.JSON(http.StatusOK, gin.H{
		"success":      true,
		"message":      "Payment berhasil dibuat",
		"token":        resp.Token,
		"redirect_url": resp.RedirectURL,
	})
}
