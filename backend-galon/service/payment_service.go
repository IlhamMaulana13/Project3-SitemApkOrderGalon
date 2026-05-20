package service

import (
	"os"

	"github.com/midtrans/midtrans-go"
	"github.com/midtrans/midtrans-go/snap"
)

func CreatePayment(orderID string, amount int64) (*snap.Response, error) {

	serverKey := os.Getenv("MIDTRANS_SERVER_KEY")

	var s snap.Client
	s.New(serverKey, midtrans.Sandbox)

	req := &snap.Request{
		TransactionDetails: midtrans.TransactionDetails{
			OrderID:  orderID,
			GrossAmt: amount,
		},

		CustomerDetail: &midtrans.CustomerDetails{
			FName: "Customer Galon",
			Email: "customer@galon.com",
		},
	}

	resp, err := s.CreateTransaction(req)

	return resp, err
}