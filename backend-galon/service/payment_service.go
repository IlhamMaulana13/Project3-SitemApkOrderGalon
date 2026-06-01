package service

import (
	"log"
	"os"

	"github.com/midtrans/midtrans-go"
	"github.com/midtrans/midtrans-go/snap"
)

type PaymentInput struct {
	OrderID       string
	Amount        int64
	CustomerName  string
	CustomerEmail string
	CustomerPhone string
}

func CreatePayment(input PaymentInput) (*snap.Response, error) {
	serverKey := os.Getenv("MIDTRANS_SERVER_KEY")

	log.Printf("MIDTRANS | OrderID: %s | Amount: %d | Customer: %s", input.OrderID, input.Amount, input.CustomerName)

	var s snap.Client
	s.New(serverKey, midtrans.Sandbox)

	req := &snap.Request{
		TransactionDetails: midtrans.TransactionDetails{
			OrderID:  input.OrderID,
			GrossAmt: input.Amount,
		},
		CustomerDetail: &midtrans.CustomerDetails{
			FName: input.CustomerName,
			Email: input.CustomerEmail,
			Phone: input.CustomerPhone,
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
