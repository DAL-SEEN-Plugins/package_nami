# NamiECR Flutter SDK

## Android & iOS -- Integration Specifications

## Overview

This document describes how to integrate the **NamiECR Flutter SDK** to
accept payments, process transactions, and return responses to the
invoking application.

The SDK is designed for developers with experience in: - POS systems -
Flutter / Android / iOS - API integrations and object-oriented
programming

------------------------------------------------------------------------

## Supported Operations

-   Initialize SDK
-   Connect Terminal
-   Disconnect Terminal
-   Initiate Payment
-   Handle Transaction Response

------------------------------------------------------------------------

## Connection Types

  Platform   Supported Connections
  ---------- -------------------------------
  iOS        TCP/IP
  Android    TCP/IP, Bluetooth, App-to-App

------------------------------------------------------------------------

## SDK Initialization

``` dart
import NamiECRSDK;
```

------------------------------------------------------------------------

## Device Connection

### TCP/IP

``` dart
await tcpSocket.connectTCP(ip, port, cashRegiNum);
```

### Bluetooth

``` dart
await _bluetoothService.connectDevice(device, cashRegiNum);
```

### App-to-App

``` dart
await _webSocketService.connect(cashRegiNum);
```

------------------------------------------------------------------------

## Disconnect Device

### TCP/IP

``` dart
tcpSocket.disconnect();
```

### Bluetooth

``` dart
_bluetoothService.disconnectDevice();
```

### App-to-App

``` dart
AppToAppSocket.disconnect();
```

------------------------------------------------------------------------

## Initiate Payment

### Cash Register Number (CRN)

CRN must be an **8-digit numeric value**

``` dart
configData.cashRegisterNumber = cashRegiNumber.text;
```

### Printing Preference

-   0 → Disable
-   1 → Enable

------------------------------------------------------------------------

### Generate Signature

``` dart
String signature = EncryptionUtil.getSha256Hash(
  config!.ecrUniqueNo ?? "",
  config!.terminalId ?? "",
);
```

------------------------------------------------------------------------

### Generate ECR Reference Number

``` dart
final String ecrRef =
"${config!.cashRegisterNumber}${EncryptionUtil.getSixDigitUniqueNumber()}";
```

------------------------------------------------------------------------

### Timestamp Format

``` text
ddMMyyHHmmss
```

------------------------------------------------------------------------

## Transaction Request Format

> Amount must be converted to a **12-digit numeric string**\
> Example: `10.25 → 000000001025`

### Purchase Example

``` dart
"${EncryptionUtil.getFormattedDateTime()};
${payAmount};
$_printTransactionType!;
$ecrRef!;"
```

------------------------------------------------------------------------

## Supported Transaction Types

-   Purchase
-   Purchase with Cashback
-   Refund
-   Pre-Authorization
-   Purchase Advice (Pre-Auth Completion)
-   Pre-Auth Extension
-   Pre-Auth Void
-   Cash Advance
-   Reversal
-   Reconciliation
-   Duplicate
-   Print Summary Report

------------------------------------------------------------------------

## Handling Response

The response includes: - PAN Number - Transaction Amount - Cash Back
Amount - Total Amount - RRN - Authorization Code - TID / MID - Card
Entry Mode - Scheme Label - Merchant Information - ECR Transaction
Reference Number - Signature

------------------------------------------------------------------------

## Known Issues & Solutions

### Issue 1: Null check operator used on a null value

**Cause:** `cashRegisterNumber` or `terminalId` is null during
transaction.

**Solution:**\
Always validate configuration values and provide fallback defaults
before initiating transactions.

------------------------------------------------------------------------

### Issue 2: FormatException -- Invalid UTF-8 byte (Bluetooth)

**Cause:**\
Bluetooth devices may send raw bytes not compatible with UTF-8.

**Solution:**\
Decode header using ASCII and payload with `allowMalformed: true`.

------------------------------------------------------------------------

## License & Confidentiality

© 2025 Girmiti Software Private Limited\
This document contains proprietary and confidential information.\
Unauthorized reproduction or distribution is strictly prohibited.
