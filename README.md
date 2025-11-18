BillWise – Smart Bill & Warranty Reminder
Final Year Senior Project – CPIS499

BillWise is a mobile application designed to help users organize, track, and manage their purchase
bills and warranty periods with intelligent reminders and automated OCR extraction.
The system uses Flutter, Firebase, and Gemini OCR to deliver a smooth, fast, and modern experience.

Features Overview:

1- Bill Management

a. Add bills manually or through image upload.

b. View and edit bills.

c. Automatic extraction of data using Gemini OCR.

d. Track return and exchange deadlines.

e. Visual progress indicators showing expiry timeline.



2- Warranty Management

a. Add warranties with product details and expiry date.

b. Automatic reminders: 4 months, 2 months, and final month.



3- Smart Notifications

a. Scheduled reminders using a Node.js FCM script.

b. Notifies users before deadlines based on predefined logic.

c. Supports cloud notifications and local app notifications.



4- Intelligent Classification

a. Each bill is automatically categorized as Active, Near Expiry, or Expired.

b. Classification is based on date comparison.

5- User Account and Profile

a. Secure login and signup using Firebase Authentication.

b. Store user profile information in Firestore.

c. Ability to edit profile information, change avatar, and logout.






System Architecture:

Flutter App
→ Firebase Authentication
→ Cloud Firestore
→ Gemini OCR API
→ Node.js scheduled notification script

Project Structure

lib/src/

auth: login, signup, authentication

bills: bill pages, models, services

warranties: warranty pages, models, services

notifications: notification logic and scheduling

profile: user profile and settings

common: shared widgets, models, utilities

Technologies Used

Frontend: Flutter 3.35.2, Dart 3.9
Backend: Firebase Auth, Firestore, Storage, Firebase Cloud Messaging
AI/OCR: Gemini 2.5 Flash/Pro
Notifications: Node.js v18+, FCM, scheduled reminders

Installation and Setup

Clone the repository:
git clone <https://github.com/Unreemable/billwise_app>
cd billwise_app

Install dependencies:
flutter pub get

Add environment variables:
Create a .env file containing:
GEMINI_API_KEY

Add Firebase configuration files:
android/app/google-services.json
ios/Runner/GoogleService-Info.plist

Run the app:
flutter run

Notification Script Setup

Inside scripts or functions folder:
npm install
node app.js




Testing

a. OCR extraction accuracy

b. Notification delivery

c. Classification correctness

d. Firestore read/write

e. Error handling



Security

a. Firebase Authentication protects user access

b. Firestore security rules prevent unauthorized data access

c. Sensitive keys stored in environment files




Team Members:

Reem Ali Najei
Wejdan Saad Al-Aziri

Supervisor: Dr. Halima Samraa

License:

This project is developed for educational purposes under CPIS499 at King Abdulaziz University.