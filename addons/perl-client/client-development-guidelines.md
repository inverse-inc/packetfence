# Writing a Fingerbank client

### This document is a work in progress

In order to use efficiently the data that is gathered by the Fingerbank project, the local library should be able to use both the local database and the public API.

Using the local database will minimize the amount of API calls which are currently limited on a hourly basis.

## Features

A fingerbank client should at least support the following features

 * Offline mode using the local database
 * Mix offline and online data for optimal performance
 * Ability to query the Fingerbank public API
 * Ability to update the local database via the client

## Offline mode

The offline mode should be able to find a combination if all the parameters are matching.

If parameters are omitted, they must be replaced by the empty value (id 0)

Optionnally, the client can find the best combination match based off all parameters (ex : 3 out of 4 match). When the match is not perfect, the Fingerbank public API should be used if a key is configured.

## Public API

The client should be able to query the Fingerbank public API if an exact match is not found locally.

The documentation of the call [is available here](https://fingerbank.inverse.ca/api_doc/1/combinations/interogate.html)

## Storing the Fingerbank result as a Device object

Given a result formatted like the one below, the library should be able to use it and build it into an endpoint object.

```
{
    "created_at": "2014-10-13T03:14:45.000Z", 
    "device": {
        "created_at": "2014-09-09T15:09:51.000Z", 
        "id": 33, 
        "inherit": null, 
        "mobile?": false, 
        "name": "Microsoft Windows Vista/7 or Server 2008 (Version 6.0)", 
        "parent_id": 1, 
        "parents": [
            {
                "approved": true, 
                "created_at": "2014-09-09T15:09:50.000Z", 
                "id": 1, 
                "inherit": null, 
                "mobile": null, 
                "name": "Windows", 
                "parent_id": null, 
                "submitter_id": null, 
                "tablet": null, 
                "updated_at": "2014-09-09T15:09:50.000Z"
            }
        ], 
        "updated_at": "2014-09-09T15:09:52.000Z"
    }, 
    "id": 5733, 
    "score": 50, 
    "updated_at": "2014-11-13T17:39:36.000Z", 
    "version": null
} 
```

### Endpoint object

An endpoint object should have the following attributes : 
 * **name** : The name of the device returned in the result
 * **version** : The version returned in the result
 * **parents** : An array of strings of the device parents (same order as in the result - closest to furtest)
 * **score** : Score returned in the result

A Fingerbank client should implement at least the following methods (the object here is refered as endpoint): 
 * **endpoint.has_parent("Generic Android")** 
  * Check if the device has for parent the device 'Generic Android'
 * **endpoint.is("Samsung Android")**
  * Check if the device is or has for parent the device 'Samsung Android'
 * **endpoint.is_android**
  * Is the device an Android device (`endpoint.is("Generic Android")`)
 * **endpoint.is_ios**
  * Is the device an iOS device (`endpoint.is("Apple iPod, iPhone or iPad")`)
 * **endpoint.is_windows**
  * Is the device a Windows device (`endpoint.is("Windows")`)
 * **endpoint.is_mac**
  * Is the device a Mac (`endpoint.is("Macintosh")`)
 * **endpoint.is_windows_phone** 
  * Is the device a Windows phone (`endpoint.is("Windows Phone")`)
 * **endpoint.is_blackberry**
  * Is the device a BlackBerry (`endpoint.is("RIM BlackBerry")`)


