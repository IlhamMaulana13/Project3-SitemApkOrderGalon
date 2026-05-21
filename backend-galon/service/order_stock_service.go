package service

import (
	"database/sql"
	"log"
)

type StockItem struct {
	ProductID int
	Qty       int
}

func ReduceStockByOrderTx(
	tx *sql.Tx,
	orderID string,
) error {

	rows, err := tx.Query(`
		SELECT product_id, qty
		FROM order_items oi
		JOIN orders o ON oi.order_id = o.id
		WHERE o.midtrans_order_id = ?
	`, orderID)

	if err != nil {
		return err
	}

	// =========================
	// SIMPAN DULU KE ARRAY
	// =========================
	var items []StockItem

	for rows.Next() {

		var item StockItem

		err := rows.Scan(
			&item.ProductID,
			&item.Qty,
		)

		if err != nil {
			rows.Close()
			return err
		}

		items = append(items, item)
	}

	// WAJIB CLOSE DULU
	rows.Close()

	// =========================
	// BARU UPDATE STOCK
	// =========================
	for _, item := range items {

		log.Println(
			"REDUCE STOCK:",
			item.ProductID,
			item.Qty,
		)

		_, err = tx.Exec(`
			UPDATE products
			SET stock = stock - ?
			WHERE id = ?
		`,
			item.Qty,
			item.ProductID,
		)

		if err != nil {
			return err
		}
	}

	return nil
}