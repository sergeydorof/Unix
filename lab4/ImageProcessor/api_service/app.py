import json
import uuid
import pika
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

app = FastAPI(title='Image Processing API')

RABBITMQ_HOST = 'rabbitmq'
QUEUE_NAME = 'image_tasks'

def send_to_queue(task_data: dict):
    try:
        connection = pika.BlockingConnection(
            pika.ConnectionParameters(host=RABBITMQ_HOST)
        )

        channel = connection.channel()
        channel.queue_declare(queue=QUEUE_NAME, durable=True)

        channel.basic_publish(
            exchange='',
            routing_key=QUEUE_NAME,
            body=json.dumps(task_data),
            properties=pika.BasicProperties(delivery_mode=2)
        )

        connection.close()
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f'Error: {str(e)}'
        )

class ImageTaskRequest(BaseModel):
    image_name: str
    filter_type: str

@app.post('/process')
def process_image(request: ImageTaskRequest):
    task_id = str(uuid.uuid4())

    task_data = {
        'task_id': task_id,
        'image_name': request.image_name,
        'filter_type': request.filter_type
    }

    send_to_queue(task_data)

    return {
        'status': 'Accepted',
        'message': 'Added to queue for processing',
        'task_id': task_id
    }