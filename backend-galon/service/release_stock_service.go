package service

import (
	"database/sql"
)

func ReleaseReservedStockTx(
	tx *sql.Tx,
	orderID string,
) error {

	rows, err := tx.Query(`
		SELECT product_id, qty
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
	}

	for rows.Next() {

		var item struct {
			ProductID int
			Qty       int
		}

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

	rows.Close()

	for _, item := range items {

		_, err = tx.Exec(`
			UPDATE products
			SET reserved_stock =
			CASE
				WHEN reserved_stock >= ?
				THEN reserved_stock - ?
				ELSE 0
			END
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
