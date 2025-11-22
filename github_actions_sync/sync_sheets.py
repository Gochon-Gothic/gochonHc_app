import os
import json
import gspread
import firebase_admin
from firebase_admin import credentials, firestore

def setup_clients():
    """Sets up and returns the gspread and firestore clients."""
    
    # Get credentials from environment variable
    gcp_sa_key_str = os.getenv('GCP_SA_KEY')
    if not gcp_sa_key_str:
        raise ValueError("GCP_SA_KEY environment variable not set.")
    
    # Parse the credentials
    creds_json = json.loads(gcp_sa_key_str)
    
    # Initialize gspread
    gc = gspread.service_account_from_dict(creds_json)
    
    # Initialize Firebase
    # Note: Use the same credentials for Firebase
    cred = credentials.Certificate(creds_json)
    
    # Check if Firebase app is already initialized
    if not firebase_admin._apps:
        firebase_admin.initialize_app(cred)
        
db = firestore.client()
    
    return gc, db

def sync_notices(gc, db, spreadsheet_id):
    """Syncs the '공지사항' sheet to the 'notices' collection in Firestore."""
    
    print("Starting notices sync...")
    
    try:
        spreadsheet = gc.open_by_key(spreadsheet_id)
        worksheet = spreadsheet.worksheet('공지사항')
        
        # Get all records from the sheet
        records = worksheet.get_all_records()
        print(f"Found {len(records)} records in '공지사항' sheet.")
        
        # Clear the existing 'notices' collection in Firestore
        # This is a simple way to handle deletions. For very large collections,
        # a more sophisticated diff-based approach would be better.
        print("Clearing existing 'notices' collection in Firestore...")
        docs = db.collection('notices').stream()
        for doc in docs:
            doc.reference.delete()
            
        # Add new records to Firestore
        print("Adding new records to 'notices' collection...")
        for record in records:
            # Ensure keys are strings and handle potential empty rows
            if not record.get('title'):
                print(f"Skipping row with no title: {record}")
                continue
                
            # Prepare data for Firestore, converting empty values to null
            notice_data = {
                'date': record.get('date', ''),
                'title': record.get('title', ''),
                'content': record.get('content', ''),
                'createdAt': firestore.SERVER_TIMESTAMP # Add a timestamp
            }
            db.collection('notices').add(notice_data)
            
        print(f"Successfully synced {len(records)} notices.")
        
    except Exception as e:
        print(f"An error occurred during notices sync: {e}")
        raise

def sync_class_counts(gc, db, spreadsheet_id):
    """Syncs the '학년별반수' sheet to Firestore."""
    
    print("Starting class counts sync...")
    
    try:
        spreadsheet = gc.open_by_key(spreadsheet_id)
        worksheet = spreadsheet.worksheet('학년별반수')
        
        # Assuming the format is:
        # A       B
        # 1학년   11
        # 2학년   11
        # 3학년   10
        
        values = worksheet.get_all_values()
        
        counts = {}
        for row in values:
            if not row or len(row) < 2:
                continue
            
            grade_str, count_str = row[0], row[1]
            if '1학년' in grade_str:
                counts['1'] = int(count_str)
            elif '2학년' in grade_str:
                counts['2'] = int(count_str)
            elif '3학년' in grade_str:
                counts['3'] = int(count_str)
                
        if len(counts) != 3:
            raise ValueError(f"Expected 3 grade counts, but found {len(counts)}. Check sheet format.")

        print(f"Found class counts: {counts}")
        
        # Save to a single document in Firestore
        doc_ref = db.collection('configs').document('class_counts')
        doc_ref.set(counts)
        
        print("Successfully synced class counts to 'configs/class_counts'.")
        
    except Exception as e:
        print(f"An error occurred during class counts sync: {e}")
        raise

def main():
    """Main function to run the sync process."""
    
    # This is the same ID from the user's Apps Script
    spreadsheet_id = '1PuH6M2yL-3A29b3cT9kl3CP7cGVbwGBms5Dhzg3E-AM'
    
    print("Setting up clients...")
    gc, db = setup_clients()
    
    sync_notices(gc, db, spreadsheet_id)
    sync_class_counts(gc, db, spreadsheet_id)
    
    print("\nSync process completed successfully!")

if __name__ == '__main__':
    main()
