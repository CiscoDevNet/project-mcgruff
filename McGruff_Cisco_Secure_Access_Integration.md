# McGruff Cisco Secure Access Integration

## Introduction

This part of project McGruff realizes integration with Cisco Secure Access, and helps during the onboarding of new employees. Utilizing the Secure Access API, we can set Secure Web Gateway (SWG) Device Settings for roaming computers, ensuring proper security measures are in place for new devices.

## High-Level Workflow

1. Add API Key
2. Generate OAuth 2.0 access token
3. Get the list of roaming computers and identify the related 'originId' (e.g., the latest added)
4. Set Secure Web Gateway Override Device Settings for new employees, enabling SWG by setting "value": "1"

## Implementation Details

### 1. Add API Key

Before starting, ensure you have obtained the necessary API credentials (Client ID and Client Secret) from Cisco Secure Access.

### 2. Generate OAuth 2.0 Access Token

Use the following Python code to generate an OAuth 2.0 access token:

```python
import requests
import base64

def get_access_token(client_id, client_secret):
    url = "https://api.sse.cisco.com/auth/v2/token"
    credentials = f"{client_id}:{client_secret}"
    encoded_credentials = base64.b64encode(credentials.encode('utf-8')).decode('utf-8')
    headers = {
        "Authorization": f"Basic {encoded_credentials}",
        "Content-Type": "application/x-www-form-urlencoded"
    }
    data = {
        "grant_type": "client_credentials"
    }
    
    response = requests.post(url, headers=headers, data=data)
    if response.status_code == 200:
        return response.json()["access_token"]
    else:
        raise Exception(f"Failed to obtain access token: {response.text}")
```

### 3. Get List of Roaming Computers

Retrieve the list of roaming computers and identify the latest added one:

```python
def get_latest_roaming_computer(access_token):
    url = "https://api.sse.cisco.com/deployments/v2/roamingcomputers"
    headers = {
        "Authorization": f"Bearer {access_token}",
        "Content-Type": "application/json"
    }
    params = {
        "limit": 1,
        "page": 1
    }
    
    response = requests.get(url, headers=headers, params=params)
    if response.status_code == 200:
        computers = response.json()
        if computers:
            return computers[0]["originId"]
        else:
            raise Exception("No roaming computers found")
    else:
        raise Exception(f"Failed to retrieve roaming computers: {response.text}")
```

### 4. Set SWG Override Device Settings

Enable SWG for the identified roaming computer:

```python
def set_swg_device_settings(access_token, origin_id):
    url = "https://api.sse.cisco.com/deployments/v2/deviceSettings/SWGEnabled/set"
    headers = {
        "Authorization": f"Bearer {access_token}",
        "Content-Type": "application/json"
    }
    data = {
        "value": "1",
        "originIds": [origin_id]
    }
    
    response = requests.post(url, headers=headers, json=data)
    if response.status_code == 200:
        print(f"Successfully enabled SWG for device with originId: {origin_id}")
    else:
        raise Exception(f"Failed to set SWG device settings: {response.text}")
```

### Main Execution

Combine the above functions in a main execution flow:

```python
def main():
    client_id = "YOUR_CLIENT_ID"
    client_secret = "YOUR_CLIENT_SECRET"
    
    try:
        access_token = get_access_token(client_id, client_secret)
        latest_origin_id = get_latest_roaming_computer(access_token)
        set_swg_device_settings(access_token, latest_origin_id)
        print("SWG settings successfully applied to the latest roaming computer.")
    except Exception as e:
        print(f"An error occurred: {str(e)}")

if __name__ == "__main__":
    main()
```

## Roadmap/Extra Features

Revoke active ACME-issued certificates and remove the zero trust user device for employees leaving the company.
https://developer.cisco.com/docs/cloud-security/revoke-certificates-for-device/


