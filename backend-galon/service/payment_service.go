package service

import (
	"database/sql"
	"log"
)

func ReduceStockByOrderTx(
	tx *sql.Tx,
	orderID string,
) error {

	rows, err := tx.Query(`
		SELECT product_id, qty
		FROM order_items
		WHERE order_id = (
			SELECT id
			FROM orders
			WHERE midtrans_order_id=?
		)
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

		_, err = tx.Exec(`
			UPDATE products
			SET stock = stock - ?
			WHERE id=?
		`, qty, productID)

		if err != nil {
			return err
		}
	}

	return nil
}