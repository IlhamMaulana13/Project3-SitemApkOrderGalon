package service

import (
	"log"

	"backend-galon/database"
)

func ReduceStockByOrder(orderID string) error {

	rows, err := database.DB.Query(`
		SELECT product_id, qty
		FROM order_items oi
		JOIN orders o ON oi.order_id = o.id
		WHERE o.midtrans_order_id = ?
	`, orderID)

	if err != nil {
		return err
	}

	defer rows.Close()

	for rows.Next() {

		var productID int
		var qty int

		err := rows.Scan(&productID, &qty)

		if err != nil {
			return err
		}

		log.Println("REDUCE STOCK:", productID, qty)

		_, err = database.DB.Exec(`
			UPDATE products
			SET stock = stock - ?
			WHERE id = ?
		`, qty, productID)

		if err != nil {
			return err
		}
	}

	return nil
}