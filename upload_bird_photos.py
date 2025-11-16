#!/usr/bin/env python3
"""
Upload bird photos to MinIO and update day index JSON
"""
import boto3
import json
import hashlib
from datetime import datetime
from pathlib import Path
import random

# MinIO configuration
MINIO_ENDPOINT = "http://localhost:9200"
ACCESS_KEY = "minioadmin"
SECRET_KEY = "minioadmin"
BUCKET = "photos"
DEVICE_ID = "dev1"

# Initialize S3 client
s3 = boto3.client(
    's3',
    endpoint_url=MINIO_ENDPOINT,
    aws_access_key_id=ACCESS_KEY,
    aws_secret_access_key=SECRET_KEY,
    region_name='us-east-1'
)

def format_timestamp_for_filename(dt):
    """Format datetime to filename format: 2025-11-15T14-23-45-123Z"""
    return dt.strftime("%Y-%m-%dT%H-%M-%S-") + f"{dt.microsecond // 1000:03d}Z"

def generate_nanoid(length=6):
    """Generate a nanoid-like string"""
    import string
    chars = string.ascii_letters + string.digits
    return ''.join(random.choice(chars) for _ in range(length))

def upload_photo(local_path, weight_grams, telemetry_data):
    """Upload a photo to MinIO and return event metadata"""
    # Read file
    with open(local_path, 'rb') as f:
        photo_data = f.read()

    # Calculate SHA256
    sha256 = hashlib.sha256(photo_data).hexdigest()

    # Generate filename
    now = datetime.now()
    timestamp_str = format_timestamp_for_filename(now)
    filename = f"{timestamp_str}-{generate_nanoid()}.jpg"
    s3_key = f"{DEVICE_ID}/{filename}"

    # Upload to MinIO
    print(f"Uploading {local_path.name} to {s3_key}...")
    s3.put_object(
        Bucket=BUCKET,
        Key=s3_key,
        Body=photo_data,
        ContentType='image/jpeg',
        Metadata={
            'weight': str(weight_grams),
            'device-id': DEVICE_ID,
            **{f'telemetry-{k}': str(v) for k, v in telemetry_data.items()}
        }
    )

    # Create event record
    event = {
        "id": generate_nanoid(8),
        "ts": int(now.timestamp() * 1000),
        "key": filename,
        "kind": "photos",
        "bytes": len(photo_data),
        "sha256": sha256,
        "weight": weight_grams,
        "telemetry": telemetry_data
    }

    print(f"[OK] Uploaded: {filename} ({len(photo_data)} bytes, {weight_grams}g)")
    return event

def update_day_index(events):
    """Update or create the day index JSON for today"""
    today = datetime.now().strftime("%Y-%m-%d")
    index_key = f"{DEVICE_ID}/indices/day-{today}.json"

    # Try to load existing index
    try:
        response = s3.get_object(Bucket=BUCKET, Key=index_key)
        day_index = json.loads(response['Body'].read().decode('utf-8'))
        print(f"Loaded existing day index: {index_key}")
    except s3.exceptions.NoSuchKey:
        day_index = {
            "deviceId": DEVICE_ID,
            "date": today,
            "generatedTs": int(datetime.now().timestamp() * 1000),
            "events": []
        }
        print(f"Creating new day index: {index_key}")

    # Add new events
    day_index["events"].extend(events)
    day_index["updatedTs"] = int(datetime.now().timestamp() * 1000)

    # Upload updated index
    s3.put_object(
        Bucket=BUCKET,
        Key=index_key,
        Body=json.dumps(day_index, indent=2).encode('utf-8'),
        ContentType='application/json'
    )

    print(f"[OK] Updated day index: {index_key} ({len(day_index['events'])} total events)")
    return day_index

def main():
    """Main upload function"""
    # Photo directory
    photo_dir = Path(__file__).parent / "app" / "app-pics" / "docker-test"

    # Bird photos with realistic telemetry data
    photos = [
        {
            "file": "1.jpg",
            "weight": 453,  # Cardinal - typical weight range
            "telemetry": {
                "battery_pct": 78,
                "solar_charging": True,
                "temperature_c": 12.5,
                "signal_strength": -45,
                "voltage_mv": 4150
            }
        },
        {
            "file": "2.jpg",
            "weight": 289,  # Blue Jay - typical weight range
            "telemetry": {
                "battery_pct": 82,
                "solar_charging": True,
                "temperature_c": 13.2,
                "signal_strength": -42,
                "voltage_mv": 4200
            }
        }
    ]

    # Upload each photo
    events = []
    for photo_info in photos:
        photo_path = photo_dir / photo_info["file"]
        if not photo_path.exists():
            print(f"[WARN] Photo not found: {photo_path}")
            continue

        event = upload_photo(
            photo_path,
            photo_info["weight"],
            photo_info["telemetry"]
        )
        events.append(event)

    # Update day index
    if events:
        day_index = update_day_index(events)
        print(f"\n[OK] Successfully uploaded {len(events)} bird photos to MinIO")
        print(f"  Device: {DEVICE_ID}")
        print(f"  Date: {day_index['date']}")
        print(f"  Total events today: {len(day_index['events'])}")
    else:
        print("[WARN] No photos were uploaded")

if __name__ == "__main__":
    main()
