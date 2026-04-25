# Paystack Documentation

Welcome to the Paystack Developer Documentation where you’ll learn how to build amazing payment experiences with the Paystack API.

## Quick start

### Accept Payments

Collect payments from cards, bank and mobile money accounts

### Send Money

Make instant transfers to bank accounts and mobile money numbers

### Identify your Customers

Verify phone numbers, bank accounts or card details

### Other ways to use Paystack

Explore libraries and tools for accepting payments without the API

## Accept a payment

Here’s how to use the Paystack API to accept a payment

### Before you begin

Authenticate all Paystack API calls using your secret keys

### Next

**post**

`api.paystack.co/transaction/initialize`

**cURL**

```bash
curl https://api.paystack.co/transaction/initialize 
-H "Authorization: Bearer YOUR_SECRET_KEY"
-H "Content-Type: application/json"
-X POST
```

## Make a transfer

Here’s how quickly you can send money on Paystack

### Before you begin

Authenticate all Paystack API calls using your secret keys

### Next

**post**

`api.paystack.co/transferrecipient`

**cURL**

```bash
curl https://api.paystack.co/transferrecipient 
-H "Authorization: Bearer YOUR_SECRET_KEY"
-H "Content-Type: application/json"
-X POST
```

## Explore demos

We’ve put together simple projects to demonstrate how to use the Paystack API for various financial services. Explore all demos or start with the most popular ones below:

# Split Payments

## In a nutshell

With split payments you can share your settlement for a transaction with another account

Implementing split payments involves:

- Create a subaccount
- Initialize a split payment

## Create a subaccount

Subaccounts can be created via the Paystack Dashboard or using the create subaccountAPI endpoint. When a subaccount is created, the subaccount_code is returned.

**cURL**

**Show Response**

```bash
curl https://api.paystack.co/subaccount
-H "Authorization: Bearer YOUR_SECRET_KEY"
-H "Content-Type: application/json"
-d '{ "business_name": "Oasis", 
      "bank_code": "058", 
      "account_number": "0123456047", 
      "percentage_charge": 30 
    }'
-X POST
```

## Verify Account Number

Please endeavour to verify that the bank account details matches what you intended. Paystack won't be liable for payouts to the wrong bank account.

## Initialize a split payment

Split payments can be initialized by using the Initialize TransactionAPI endpoint and passing the parameter subaccount: "ACCT_xxxxxxxxxx".

**cURL**

**Show Response**

```bash
curl https://api.paystack.co/transaction/initialize
-H "Authorization: Bearer YOUR_SECRET_KEY"
-H "Content-Type: application/json"
-d '{ "email": "customer@email.com", 
      "amount": "20000", 
      "subaccount": "ACCT_xxxxxxxxx" 
    }'
-X POST
```

Split payments can be used in the following scenario:

- Shared payment between service provider and platform provider
- Split profit between different vendors
- Separate school fees in different account for example Tuition, Accomodation, Excursion

## Flat fee

By default, payments are split by percentage. For example, if a subaccount was created with percentage_charge: 20, 20% goes to the main account and the rest goes to the subaccount.

However, you can override this default and specify a flat fee that goes into your main account. To do this, pass the transaction_charge key when initializing a transaction.

In the snippet below, the main account gets a flat fee of 10000 and the subaccount gets the rest:

**cURL**

**Show Response**

```bash
curl https://api.paystack.co/transaction/initialize
-H "Authorization: Bearer YOUR_SECRET_KEY"
-H "Content-Type: application/json"
-d '{ "email": "customer@email.com", 
      "amount": "20000",
      "subaccount": "ACCT_xxxxxxxxx", 
      "transaction_charge": 10000 
    }'
-X POST
```

## Bearer of transaction fee

By default, the Paystack charges are borne by the main account. To change this to a subaccount, pass the param bearer: "subaccount" while initializing a transaction.

**cURL**

**Show Response**

```bash
curl https://api.paystack.co/transaction/initialize
-H "Authorization: Bearer YOUR_SECRET_KEY"
-H "Content-Type: application/json"
-d '{ "email": "customer@email.com", 
      "amount": "20000",
      "subaccount": "ACCT_xxxxxxxxx", 
      "bearer": "subaccount" 
    }'
-X POST
```

# Accept Payments

## In a nutshell

To accept a payment, create a transaction using our API, our client Javascript library, Popup JS, or our SDKs. Every transaction includes a link that can be used to complete payment.

## Popup

Paystack Popup is a Javascript library that allow developers to build a secure and convenient payment flow for their web applications. You can add it to your frontend app via CDN, NPM or Yarn:

**CDNNPMYarn**

```html
<script src="https://js.paystack.co/v2/inline.js">
```

If you used NPM or Yarn, ensure you import the library as shown below:

```javascript
import PaystackPop from '@paystack/inline-js'
```

With the library successfully installed, you can now begin the three-step integration process:

- Initialize transaction
- Complete transaction
- Verify transaction status

## Initialize transaction

To get started, you need to initialize the transaction from your backend. Initializing the transaction from the backend ensures you have full control of the transaction details. To do this, make a POST request from your backend to the Initialize TransactionAPI endpoint:

**cURL**

**Show Response**

```bash
curl https://api.paystack.co/transaction/initialize
-H "Authorization: Bearer YOUR_SECRET_KEY"
-H "Content-Type: application/json"
-d '{ "email": "customer@email.com", 
      "amount": "500000"
    }'
-X POST
```

The data object of the response contains an access_code parameter that's needed to complete the transaction. You should store this parameter and send it to your frontend.

## Don't use your secret key in your frontend

Never call the Paystack API directly from your frontend to avoid exposing your secret key on the frontend. All requests to the Paystack API should be initiated from your server, and your frontend gets the response from your server.

## Complete transaction

Your frontend app should make a request to your backend to initialize the transaction and get the access_code as described in the previous section. On getting the access_code from your backend, you can then use Popup to complete the transaction:

```javascript
const popup = new PaystackPop()
popup.resumeTransaction(access_code)
```

The resumeTransaction method triggers the checkout in the browser, allowing the user to choose their preferred payment channel to complete the transaction. You can check out the InlineJS reference guide to learn about the features available in Popup V2.

## Verify transaction status

Finally, you need to confirm the status of the transaction by using either webhooks or the verify transactions endpoint. Regardless of the method used, you need to use the following parameter to confirm if you should deliver value to your customer or not:

| Parameter | Description |
|---|---|
| data.status | This indicates if the payment is successful or not |
| data.amount | This indicates the price of your product or service in the lower denomination of your currency. |

## Verify amount

When verifying the status of a transaction, you should also verify the amount to ensure it matches the value of the service you are delivering. If the amount doesn't match, don't deliver value to the customer.

## Redirect

Here, you call the Initialize TransactionAPI from your server to generate a checkout link, then redirect your users to the link so they can pay. After payment is made, the users are returned to your website at the callback_url

## Warning

Confirm that your server can conclude a TLSv1.2 connection to Paystack's servers. Most up-to-date software have this capability. Contact your service provider for guidance if you have any SSL errors.

## Collect customer information

To initialize the transaction, you'll need to pass information such as email, first name, last name amount, transaction reference, etc. Email and amount are required. You can also pass any other additional information in the metadata object field.

The customer information can be retrieved from your database, session or cookie if you already have it stored, or from a form like in the example below.

**HTML**

```html
<form action="/save-order-and-pay" method="POST"> 
  <input type="hidden" name="user_email" value="<?php echo $email; ?>"> 
  <input type="hidden" name="amount" value="<?php echo $amount; ?>"> 
  <input type="hidden" name="cartid" value="<?php echo $cartid; ?>"> 
  <button type="submit" name="pay_now" id="pay-now" title="Pay now">Pay now</button>
</form>
```

## Initialize transaction

When a customer clicks the payment action button, initialize a transaction by making a POST request to our API. Pass the email, amount and any other parameters to the Initialize TransactionAPI endpoint.

If the API call is successful, we will return an authorization URL which you will redirect to for the customer to input their payment information to complete the transaction.

### Important notes

- The amount should be in the subunit of the supported currency.
- We used the cart_id from the form above as our transaction reference. You should use a unique transaction identifier from your system as your reference.
- We set the callback_url in the transaction_data array. If you don't do this, we'll use the one that's set on your dashboard. Setting it in the code allows you to be flexible with the redirect URL if you need to
- If you don't set a callback URL on the dashboard or on the code, the users won't be redirected back to your site after payment.
- You can set test callback URLs for test transactions and live callback URLs for live transactions.

**PHP**

```php
<?php
  $url = "https://api.paystack.co/transaction/initialize";

  $fields = [
    'email' => "customer@email.com",
    'amount' => "20000",
    'callback_url' => "https://hello.pstk.xyz/callback",
    'metadata' => ["cancel_action" => "https://your-cancel-url.com"]
  ];

  $fields_string = http_build_query($fields);

  //open connection
  $ch = curl_init();
  
  //set the url, number of POST vars, POST data
  curl_setopt($ch,CURLOPT_URL, $url);
  curl_setopt($ch,CURLOPT_POST, true);
  curl_setopt($ch,CURLOPT_POSTFIELDS, $fields_string);
  curl_setopt($ch, CURLOPT_HTTPHEADER, array(
    "Authorization: Bearer SECRET_KEY",
    "Cache-Control: no-cache",
  ));
  
  //So that curl_exec returns the contents of the cURL; rather than echoing it
  curl_setopt($ch,CURLOPT_RETURNTRANSFER, true); 
  
  //execute post
  $result = curl_exec($ch);
  echo $result;
?>
```

## Verify transaction

If the transaction is successful, Paystack will redirect the user back to a callback_url you set. We'll append the transaction reference in the URL. In the example above, the user will be redirected to http://your_website.com/postpayment_callback.php?reference=YOUR_REFERENCE.

So you retrieve the reference from the URL parameter and use that to call the verify endpoint to confirm the status of the transaction. Learn more about verifying transactions.

It's very important that you call the Verify endpoint to confirm the status of the transactions before delivering value. Just because the callback_url was visited doesn't prove that transaction was successful.

## Handle webhook

When a payment is successful, Paystack sends a charge.success webhook event to webhook URL that you provide. Learn more about using webhooks.

## Mobile SDKs

With our mobile SDKs, we provide a collection of methods and interfaces tailored to the aesthetic of the platform. Transactions are initiated on the server and completed in the SDK. The SDK requires an access_code to display the UI component that accepts payment.

To get the access_code, you need to initialize a transaction by making a POST request on your server to the Initialize TransactionAPI endpoint:

**cURL**

**Show Response**

```bash
curl https://api.paystack.co/transaction/initialize
-H "Authorization: Bearer YOUR_SECRET_KEY"
-H "Content-Type: application/json"
-d '{ "email": "customer@email.com", 
      "amount": "500000"
    }'
-X POST
```

On a successful initialization of the transaction, you get a response that contains an access_code. You need to return this access_code back to your mobile app.

# Introduction

Generally, when you make a request to an API endpoint, you expect to get a near-immediate response. However, some requests may take a long time to process, which can lead to timeout errors. To prevent a timeout error, a pending response is returned. Since your records need to be updated with the final state of the request, you need to either:

- Make a request for an update (popularly known as polling) or,
- Listen to events by using a webhook URL.

## Helpful Tip

We recommend that you use webhook to provide value to your customers over using callbacks or polling. With callbacks, we don't have control over what happens on the customer's end. Neither do you. Callbacks can fail if the network connection on a customer's device fails or is weak or if the device goes off after a transaction.

## Polling vs webhooks

Image showing a comparison between polling and webhooks

Polling requires making a GET request at regular intervals to get the final status of a request. For example, when a customer makes a payment for a transaction, you keep making a request for the transaction status until you get a successful transaction status.

With webhooks, the resource server, Paystack in this case, sends updates to your server when the status of your request changes. The change in status of a request is known as an event. You’ll typically listen to these events on a POST endpoint called your webhook URL.

The table below highlights some differences between polling and webhooks:

| Polling | Webhooks |
|---|---|
| Mode of update | Manual |
| Rate limiting | Yes |
| Impacted by scaling | Yes |

| Webhooks |
|---|
| Automatic |
| No |
| No |

## Create a webhook URL

A webhook URL is simply a POST endpoint that a resource server sends updates to. The URL needs to parse a JSON request and return a 200 OK:

**NodePHP**

```javascript
// Using Express
app.post("/my/webhook/url", function(req, res) {
    // Retrieve the request's body
    const event = req.body;
    // Do something with event
    res.send(200);
});
```

When your webhook URL receives an event, it needs to parse and acknowledge the event. Acknowledging an event means returning a 200 OK in the HTTP header. Without a 200 OK in the response header, events are sent for the next 72 hours:

- In live mode, webhook events are sent every 3 minutes for the first 4 tries, then retried hourly for the next 72 hours
- In test mode, webhook events are sent hourly for 10 hours, with a request timeout of 30 seconds.

## Avoid long-running tasks

If you have extra tasks in your webhook function, you should return a 200 OK response immediately. Long-running tasks lead to a request timeout and an automatic error response from your server. Without a 200 OK response, the retry as described in the proceeding paragraph.

## Verify event origin

Since your webhook URL is publicly available, you need to verify that events originate from Paystack and not a bad actor. There are two ways to ensure events to your webhook URL are from Paystack:

- Signature validation
- IP whitelisting

## Signature validation

Events sent from Paystack carry the x-paystack-signature header. The value of this header is a HMAC SHA512 signature of the event payload signed using your secret key. Verifying the header signature should be done before processing the event:

**Node**

```javascript
const crypto = require('crypto');
const secret = process.env.SECRET_KEY;
// Using Express
app.post("/my/webhook/url", function(req, res) {
    //validate event
    const hash = crypto.createHmac('sha512', secret).update(JSON.stringify(req.body)).digest('hex');
    if (hash == req.headers['x-paystack-signature']) {
    // Retrieve the request's body
    const event = req.body;
    // Do something with event  
    }
    res.send(200);
});
```

## IP whitelisting

With this method, you only allow certain IP addresses to access your webhook URL while blocking out others. Paystack will only send webhooks from the following IP addresses:

- 52.31.139.75
- 52.49.173.169
- 52.214.14.220

You should whitelist these IP addresses and consider requests from other IP addresses a counterfeit.

## Whitelisting is domain independent

The IP addresses listed above are applicable to both test and live environments. You can whitelist them in your staging and production environments.

## Go live checklist

Now that you’ve successfully created your webhook URL, here are some ways to ensure you get a delightful experience:

- Add the webhook URL on your Paystack dashboard
- Ensure your webhook URL is publicly available (localhost URLs can't receive events)
- If using .htaccess remember to add the trailing / to the URL
- Test your webhook to ensure you’re getting the JSON body and returning a 200 OK HTTP response
- If your webhook function has long-running tasks, you should first acknowledge receiving the webhook by returning a 200 OK before proceeding with the long-running tasks
- If we don’t get a 200 OK HTTP response from your webhooks, we flagged it as a failed attempt
- In the live mode, failed attempts are retried every 3 minutes for the first 4 tries, then retried hourly for the next 72 hours
- In the test mode, failed attempts are retried hourly for the next 10 hours. The timeout for each attempt is 30 seconds.

## Supported events

Customer Identification FailedCustomer Identification SuccessfulDispute CreatedDispute ReminderDispute ResolvedDVA Assignment FailedDVA Assignment SuccessfulInvoice CreatedInvoice FailedInvoice UpdatedPayment Request PendingPayment Request SuccessfulRefund FailedRefund PendingRefund ProcessedRefund ProcessingSubscription CreatedSubscription DisabledSubscription Not RenewingSubscriptions with Expiring CardsTransaction SuccessfulTransfer SuccessfulTransfer FailedTransfer Reversed

```json
{
  "event": "customeridentification.failed",
  "data": {
    "customer_id": 82796315,
    "customer_code": "CUS_XXXXXXXXXXXXXXX",
    "email": "email@email.com",
    "identification": {
      "country": "NG",
      "type": "bank_account",
      "bvn": "123*****456",
      "account_number": "012****345",
      "bank_code": "999991"
    },
    "reason": "Account number or BVN is incorrect"
  }
}
```

## Types of events

Here are the events we currently raise. We would add more to this list as we hook into more actions in the future.

| Event | Description |
|---|---|
| charge.dispute.create | A dispute was logged against your business |
| charge.dispute.remind | A logged dispute hasn't been resolved |
| charge.dispute.resolve | A dispute has been resolved |
| charge.success | A successful charge was made |
| customeridentification.failed | A customer ID validation has failed |
| customeridentification.success | A customer ID validation was successful |
| dedicatedaccount.assign.failed | This is sent when a DVA couldn't be created and assigned to a customer |
| dedicatedaccount.assign.success | This is sent when a DVA has been successfully created and assigned to a customer |
| invoice.create | An invoice has been created for a subscription on your account. This usually happens 3 days before the subscription is due or whenever we send the customer their first pending invoice notification |
| invoice.payment_failed | A payment for an invoice failed |
| invoice.update | An invoice has been updated. This usually means we were able to charge the customer successfully. You should inspect the invoice object returned and take necessary action |
| paymentrequest.pending | A payment request has been sent to a customer |
| paymentrequest.success | A payment request has been paid for |
| refund.failed | Refund can't be processed. Your account will be credited with refund amount |
| refund.pending | Refund initiated, waiting for response from the processor. |
| refund.processed | Refund has successfully been processed by the processor. |
| refund.processing | Refund has been received by the processor. |
| subscription.create | A subscription has been created |
| subscription.disable | A subscription on your account has been disabled |
| subscription.expiring_cards | Contains information on all subscriptions with cards that are expiring that month. Sent at the beginning of the month, to merchants using Subscriptions |
| subscription.not_renew | A subscription on your account's status has changed to non-renewing. This means the subscription won't be charged on the next payment date |
| transfer.failed | A transfer you attempted has failed |
| transfer.success | A successful transfer has been completed |
| transfer.reversed | A transfer you attempted has been reversed |

# Verify Payments

## In a nutshell

The Verify Transaction API allows you confirm the status of a customer's transaction.

## Transaction statuses

Webhooks are the preferred option for confirming a transaction status, but we currently send webhook events for just successful transactions. However, a transaction can have the following statuses:

| Status | Meaning |
|---|---|
| abandoned | The customer hasn't completed the transaction. |
| failed | The transaction failed. For more information on why, refer to the message/gateway response. |
| ongoing | The customer is currently trying to carry out an action to complete the transaction. This can get returned when we're waiting on the customer to enter an otp or to make a transfer (for a pay with transfer transaction). |
| pending | The transaction is currently in progress. |
| processing | Same as pending, but for direct debit transactions. |
| queued | The transaction has been queued to be processed later. Only possible on bulk charge transactions. |
| reversed | The transaction was reversed. This could mean the transaction was refunded, or a chargeback was successfully logged for this transaction. |
| success | The transaction was successfully processed. |

## Verify a transaction

You do this by making a GET request to the Verify TransactionAPI endpoint from your server using your transaction reference. This is dependent on the method you used to initialize the transaction.

## From Popup or mobile SDKs

You'll have to send the reference to your server, then from your server you call the verify endpoint.

## From the Redirect API

You initiate this request from your callback URL. The transaction reference is returned as a query parameter to your callback URL.

## Helpful Tip

If you offer digital value like airtime, wallet top-up, digital credit, etc, always confirm that you haven't already delivered value for that transaction to avoid double fulfillments, especially, if you also use webhooks.

Here's a code sample for verifying transactions:

**cURL**

**Show Response**

```bash
#!/bin/sh
curl https://api.paystack.co/transaction/verify/:reference
-H "Authorization: Bearer YOUR_SECRET_KEY"
-X GET
```