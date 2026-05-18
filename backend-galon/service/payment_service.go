package service

import (
    "github.com/midtrans/midtrans-go"
    "github.com/midtrans/midtrans-go/snap"
)

func CreatePayment(orderID string, amount int64) (*snap.Response, error) {

    var s = snap.Client{}
    s.New("SERVER_KEY_KAMU", midtrans.Sandbox)

    req := &snap.Request{
        TransactionDetails: midtrans.TransactionDetails{
            OrderID:  orderID,
            GrossAmt: amount,
        },
    }

    resp, err := s.CreateTransaction(req)

    return resp, err
}