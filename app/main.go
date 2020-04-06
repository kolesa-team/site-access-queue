package main

import (
	"github.com/go-redis/redis"
	"github.com/sirupsen/logrus"
	"os"
	"time"
)

func main() {
	redisAddr := os.Getenv("REDIS_ADDR")
	debug := os.Getenv("DEBUG")

	if len(redisAddr) == 0 {
		redisAddr = "redis:6379"
	}

	if debug == "1" {
		logrus.SetLevel(logrus.DebugLevel)
	}

	c := GetClient(redisAddr)

	logrus.Infoln("Watching expired redis keys")

	// подписываемся на события истекания ключей (=бездействующие пользователи),
	// и увеличиваем счетчик свободных мест
	pubsub := c.Subscribe("__keyevent@0__:expired")
	ch := pubsub.Channel()

	for msg := range ch {
		logrus.Debugln(msg.Channel, msg.Payload)
		c.Incr("global_offset")
	}
}

func GetClient(addr string) *redis.Client {
	opts := &redis.Options{
		Addr:        addr,
		ReadTimeout: time.Second * 2,
		PoolSize:    20,
	}

	client := redis.NewClient(opts)

	for {
		_, err := client.Ping().Result()
		if err != nil {
			logrus.WithError(err).Error("Could not connect to redis")
			time.Sleep(time.Second)
		} else {
			break
		}
	}

	return client
}
