import os
import time
import json
import pika

RABBITMQ_HOST = 'rabbitmq'
QUEUE_NAME = 'image_tasks'
WORKER_NAME = os.getenv('HOSTNAME', 'Worker-Unknown')

def callback(ch, method, properties, body):
    try:
        task = json.loads(body.decode())
        print(
            f"[{WORKER_NAME}] got task {task['task_id']}: processing file '{task['image_name']}'",
            flush=True
        )

        time.sleep(10)

        print(
            f"[{WORKER_NAME}] successful completed: effect '{task['filter_type']}' used to '{task['image_name']}' (ID: {task['task_id']})",
            flush=True
        )

        ch.basic_ack(delivery_tag=method.delivery_tag)
    except Exception as e:
        print(f"[{WORKER_NAME}] error when processing task: {e}", flush=True)
        ch.basic_nack(delivery_tag=method.delivery_tag, requeue=True)

def main():
    print(f"[{WORKER_NAME}] waiting for connection to RabbitMQ...")

    while True:
        try:
            connection = pika.BlockingConnection(
                pika.ConnectionParameters(host=RABBITMQ_HOST)
            )

            channel = connection.channel()
            channel.queue_declare(queue=QUEUE_NAME, durable=True)
            channel.basic_qos(prefetch_count=1)
            channel.basic_consume(queue=QUEUE_NAME, on_message_callback=callback)

            print(
                f"[{WORKER_NAME}] Successful connected, waiting for messages...",
                flush=True
            )

            break
        except pika.exceptions.AMQPConnectionError:
            print(f"[{WORKER_NAME}] RabbitMQ is not ready")
            time.sleep(3)

    channel.start_consuming()

if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        print('Worker stopped')