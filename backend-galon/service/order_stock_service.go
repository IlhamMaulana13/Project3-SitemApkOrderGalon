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
		SELECT product_id, qty, service
		FROM order_items oi
		JOIN orders o ON oi.order_id = o.id
		WHERE o.midtrans_order_id=?
	`, orderID)

	if err != nil {
		return err
	}

	var items []struct {
		ProductID int
		Qty       int
		Service   string
	}

	for rows.Next() {

		var item struct {
			ProductID int
			Qty       int
			Service   string
		}

		err := rows.Scan(
			&item.ProductID,
			&item.Qty,
			&item.Service,
		)

		if err != nil {
			rows.Close()
			return err
		}

		items = append(items, item)
	}

	rows.Close()

	for _, item := range items {
		if item.Service == "Isi Ulang" {
			log.Println("SKIP STOCK REDUCTION FOR ISI ULANG:", item.ProductID, item.Qty)
			continue
		}
		log.Println("REDUCE STOCK:", item.ProductID, item.Qty)

		_, err = tx.Exec(`
			UPDATE products
			SET
				stock = stock - ?,
				reserved_stock = reserved_stock - ?
			WHERE id=?
		`,
			item.Qty,
			item.Qty,
			item.ProductID,
		)

		if err != nil {
			return err
		}
	}

	return nil
}
