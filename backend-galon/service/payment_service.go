package service

import (
	"os"

	"github.com/midtrans/midtrans-go"
	"github.com/midtrans/midtrans-go/snap"
)

func CreatePayment(orderID string, amount int64) (*snap.Response, error) {

	var s = snap.Client{}
	midtrans.ServerKey = os.Getenv("MIDTRANS_SERVER_KEY")

	req := &snap.Request{
		TransactionDetails: midtrans.TransactionDetails{
			OrderID:  orderID,
			GrossAmt: amount,
		},
	}

	resp, err := s.CreateTransaction(req)

	return resp, err
}
