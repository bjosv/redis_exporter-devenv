package main

import (
	"crypto/tls"
	"crypto/x509"
	"io/ioutil"
	"log"
	"os"
	"strconv"
	"strings"

	"github.com/gomodule/redigo/redis"

	"github.com/fsnotify/fsnotify"
)

func main() {
	log.Println("Start..")

	files := strings.Split(getEnv("WATCH_FILES", ""), ":")
	log.Printf("%+v\n", files)

	watcher, err := fsnotify.NewWatcher()
	if err != nil {
		log.Fatal(err)
	}
	defer watcher.Close()

	done := make(chan bool)
	update := make(chan bool)
	go func() {
		for {
			select {
			case event, ok := <-watcher.Events:
				if !ok {
					return
				}
				log.Println("event:", event)

				update <- true

				if event.Op&fsnotify.Write == fsnotify.Write {
					log.Println("modified file:", event.Name)
				}
			case err, ok := <-watcher.Errors:
				if !ok {
					return
				}
				log.Println("error:", err)
			}
		}
	}()
	for _, file := range files {
		log.Println("Add watch on file:", file)
		err = watcher.Add(file)
		if err != nil {
			log.Fatal(err)
		}
	}

	tlsCertFile := getEnv("REDIS_TLS_CLIENT_CERT_FILE", "")
	tlsKeyFile := getEnv("REDIS_TLS_CLIENT_KEY_FILE", "")
	log.Println("TLS: appending keypair:", tlsCertFile, tlsKeyFile)
	var tlsClientCertificates []tls.Certificate
	cert, err := tls.LoadX509KeyPair(tlsCertFile, tlsKeyFile)
	tlsClientCertificates = append(tlsClientCertificates, cert)

	var tlsCaCertificates *x509.CertPool
	caCertFile := getEnv("REDIS_TLS_CA_CERT_FILE", "")
	log.Println("TLS: appending CA file:", caCertFile)
	caCert, err := ioutil.ReadFile(caCertFile)
	if err != nil {
		log.Fatalf("Couldn't load TLS Ca certificate '%s', err: %s", caCertFile, err)
	}
	tlsCaCertificates = x509.NewCertPool()
	tlsCaCertificates.AppendCertsFromPEM(caCert)

	uri := getEnv("REDIS_URI", "")
	options := []redis.DialOption{
		redis.DialTLSConfig(&tls.Config{
			InsecureSkipVerify: getEnvBool("REDIS_SKIP_TLS_VERIFICATION", false),
			Certificates:       tlsClientCertificates,
			RootCAs:            tlsCaCertificates,
		}),
	}

	c, err := redis.DialURL(uri, options...)
	if err != nil {
		log.Fatalf("Couldn't connect to redis instance '%s', err: %s", uri, err)
	}
	defer c.Close()

	log.Println("Connected to:", uri)

	for {
		select {
		case <-done:
			os.Exit(0)
		case <-update:
			log.Println("Send TLS config update command")
			_, err := c.Do("CONFIG", "SET", "tls-cert-file", "/tls-data/redis.crt")
			if err != nil {
				log.Println("tls-cert-file config update failed", err)
			}
			_, err = c.Do("CONFIG", "SET", "tls-key-file", "/tls-data/redis.key")
			if err != nil {
				log.Println("tls-key-file update failed", err)
			}
		}
	}
}

func getEnv(key string, defaultVal string) string {
	if envVal, ok := os.LookupEnv(key); ok {
		return envVal
	}
	return defaultVal
}

func getEnvBool(key string, defaultVal bool) bool {
	if envVal, ok := os.LookupEnv(key); ok {
		envBool, err := strconv.ParseBool(envVal)
		if err == nil {
			return envBool
		}
	}
	return defaultVal
}
