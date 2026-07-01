package service

import (
	"database/sql"
	"fmt"
)

func ReleaseReservedStockTx(
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
			continue
		}

		// Lepas reservasi pada kolom stok yang sesuai layanan.
		reservedCol := "reserved_stock_new"
		if item.Service == "Sewa" {
			reservedCol = "reserved_stock_rental"
		}

		_, err = tx.Exec(fmt.Sprintf(`
			UPDATE products
			SET %s =
			CASE
				WHEN %s >= ?
				THEN %s - ?
				ELSE 0
			END
			WHERE id=?
		`, reservedCol, reservedCol, reservedCol),
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
