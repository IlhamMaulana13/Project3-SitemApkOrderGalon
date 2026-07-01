package service

import (
	"database/sql"
	"fmt"
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

		// Kurangi kolom stok sesuai jenis layanan:
		// "Sewa" -> stok sewa, selain itu (Beli Baru) -> stok baru.
		stockCol := "stock_new"
		reservedCol := "reserved_stock_new"
		if item.Service == "Sewa" {
			stockCol = "stock_rental"
			reservedCol = "reserved_stock_rental"
		}

		log.Println("REDUCE STOCK:", item.ProductID, item.Qty, item.Service)

		_, err = tx.Exec(fmt.Sprintf(`
			UPDATE products
			SET
				%s = %s - ?,
				%s = CASE WHEN %s >= ? THEN %s - ? ELSE 0 END
			WHERE id=?
		`, stockCol, stockCol, reservedCol, reservedCol, reservedCol),
			item.Qty,
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
