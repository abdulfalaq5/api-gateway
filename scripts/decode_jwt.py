#!/usr/bin/env python3
import json
import base64
import sys
import datetime

def decode_jwt(token):
    try:
        # JWT has 3 parts: header.payload.signature
        parts = token.split('.')
        if len(parts) != 3:
            print("Error: Invalid JWT format. Expected 3 parts separated by dots.")
            return

        payload_b64 = parts[1]
        # Fix padding if necessary
        padding = len(payload_b64) % 4
        payload_b64 += '=' * padding
        
        payload_data = base64.urlsafe_b64decode(payload_b64).decode('utf-8')
        payload = json.loads(payload_data)
        
        print("\n=== JWT Payload ===")
        print(json.dumps(payload, indent=2))
        
        if 'iat' in payload and 'exp' in payload:
            iat = payload['iat']
            exp = payload['exp']
            duration = exp - iat
            
            print("\n=== Time Analysis ===")
            print(f"Issued At (iat):  {datetime.datetime.fromtimestamp(iat)} (Unix: {iat})")
            print(f"Expires At (exp): {datetime.datetime.fromtimestamp(exp)} (Unix: {exp})")
            print(f"Duration:         {duration} seconds ({duration/3600:.1f} hours)")
            
            now = datetime.datetime.now().timestamp()
            if now > exp:
                print(f"Status:           EXPIRED (by {int(now - exp)} seconds ago)")
            else:
                print(f"Status:           VALID (expires in {int(exp - now)} seconds)")
                
    except Exception as e:
        print(f"Error decoding token: {str(e)}")

if __name__ == "__main__":
    if len(sys.argv) > 1:
        token = sys.argv[1]
    else:
        print("Enter JWT Token:")
        token = input().strip()
        # Remove 'Bearer ' prefix if present
        if token.lower().startswith('bearer '):
            token = token[7:]
    
    decode_jwt(token)
