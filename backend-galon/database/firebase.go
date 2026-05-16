package database

import (
	"context"
	"log"

	firebase "firebase.google.com/go"
	"firebase.google.com/go/messaging"
	"google.golang.org/api/option"
)

var FirebaseApp *firebase.App

func InitFirebase() {

	opt := option.WithCredentialsFile(
		"serviceAccountKey.json",
	)

	app, err := firebase.NewApp(
		context.Background(),
		nil,
		opt,
	)

	if err != nil {
		log.Fatal(err)
	}

	FirebaseApp = app
}

func SendNotification(
	token string,
	title string,
	body string,
) {

	client, err := FirebaseApp.Messaging(
		context.Background(),
	)

	if err != nil {
		log.Println(err)
		return
	}

	message := &messaging.Message{
		Token: token,

		Notification: &messaging.Notification{
			Title: title,
			Body:  body,
		},
	}

	_, err = client.Send(
		context.Background(),
		message,
	)

	if err != nil {
		log.Println(err)
		return
	}

	log.Println("Notif berhasil dikirim")
}
