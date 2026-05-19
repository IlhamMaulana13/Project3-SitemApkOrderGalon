package service

import (
	"log"
	"os"

	"github.com/midtrans/midtrans-go"
	"github.com/midtrans/midtrans-go/snap"
)

func CreatePayment(orderID string, amount int64) (*snap.Response, error) {

	serverKey := os.Getenv("MIDTRANS_SERVER_KEY")

	log.Println("SERVER KEY:", serverKey)
	log.Println("ORDER ID:", orderID)
	log.Println("AMOUNT:", amount)

	var s snap.Client
	s.New(serverKey, midtrans.Sandbox)

	req := &snap.Request{
		TransactionDetails: midtrans.TransactionDetails{
			OrderID:  orderID,
			GrossAmt: amount,
		},
	}

	resp, err := s.CreateTransaction(req)

	if err != nil {
		log.Println("MIDTRANS CREATE ERROR:", err)
		return nil, err
	}

	log.Println("MIDTRANS SUCCESS:", resp.RedirectURL)

	return resp, nil
}