package database

import (
	"database/sql"
	"log"

	_ "github.com/go-sql-driver/mysql"
)

var DB *sql.DB

func ConnectDB() {

	connection := "golangapp:Password123!@tcp(127.0.0.1:3306)/db_galon"

	db, err := sql.Open("mysql", connection)

	if err != nil {
		log.Fatal(err)
	}

	DB = db

	log.Println("Database Connected")
}
