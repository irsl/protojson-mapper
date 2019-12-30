# protojson to simple json

Google's Protocol Buffers are used as JSON text by some APIs (like Hangouts); the mime type is application/json+protobuf and looks like an array of arrays.
This experimental poc project helps in reconstructing the proto definition file based on the error messages the server side responds with.

## protojson-mapper.pl

Example:

```
perl protojson-mapper.pl "https://chat-pa.clients6.google.com/chat/v1/presence/querypresence?key=AIzaSyD7InnYR3VKdb4j2rMUEbTCIr2VyEazl6k"  "https://hangouts.google.com" "SID=...; HSID=...; SSID=...; APISID=...; SAPISID=...; " > querypresence.proto
```

The output file will look like this:

```
message Requestquerypresence {
  message ClientRequestHeader {
    message ClientClientVersion {
      enum client_id_enum {
        CLIENT_ID_UNKNOWN = 0;
      }

      enum build_type_enum {
        BUILD_TYPE_UNKNOWN = 0;
      }

      optional client_id_enum client_id                 = 1;
      optional build_type_enum build_type               = 2;
      optional string major_version                     = 3;
      optional int64 version                            = 4;
      optional string device_os_version                 = 5;
      optional string device_hardware                   = 6;
      optional int32 android_sdk_api_level              = 7;
    }

    message ClientClientIdentifier {
      optional string resource                          = 1;
      optional string client_id                         = 2;
      optional string self_fanout_id                    = 3;
      optional string participant_log_id                = 4;
    }

    message ClientClientInstrumentationInfo {
      optional int64 chat_message_sequence_number       = 1;
      optional string client_request_id                 = 2;
    }

    message RtcClient {
      enum device_enum {
        DEVICE_UNKNOWN = 0;
      }

      enum application_enum {
        APPLICATION_UNKNOWN = 0;
      }

      enum platform_enum {
        PLATFORM_UNKNOWN = 0;
      }

      optional device_enum device                       = 1;
      optional application_enum application             = 2;
      optional platform_enum platform                   = 3;
    }

    message ClientCacheHash {
      optional string update_id                         = 1;
      optional uint64 hash_diff                         = 2;
      optional uint64 hash_rollup                       = 3;
      optional uint64 version                           = 4;
    }

    optional ClientClientVersion client_version       = 1;
    optional ClientClientIdentifier client_identifier = 2;
    optional ClientClientInstrumentationInfo client_instrumentation_info = 3;
    optional string language_code                     = 4;
    optional bool request_header                      = 5;
    optional uint32 retry_attempt                     = 6;
    optional RtcClient rtc_client                     = 7;
    optional string client_generated_request_id       = 8;
    optional ClientCacheHash local_state_hash         = 9;
  }

  message ClientParticipantId {
    optional string gaia_id                           = 1;
    optional string chat_id                           = 2;
  }

  enum field_mask_enum {
    FIELD_MASK_UNKNOWN = 0;
  }

  optional ClientRequestHeader request_header       = 1;
  repeated ClientParticipantId participant_id       = 2;
  optional field_mask_enum field_mask               = 3;
}
```



## protojson-to-json.pl

You can use this helper script to transform the protojson representation of an eavesdropped (your browsers inspect window) message payload to build a human readable simple json output of it.

Something like:

```
perl protojson-to-json.pl querypresence.proto < captured-querypresence.protojson

```

Given the protojson looked like:

```
[[[6,3,"babel-chat.frontend_20191215.07_p0",1576448357],["lcsw_hangouts_CEDE12C7","D2617B211AD8FD18"],null,"hu",true],[["104323452778803782544"]],[2,3,10,0,-1,1,4,5,6,7,8,9,11,12,13,14,15,16,17,18,19]]
```

The output will look something like:

```
{
   "field_mask" : [
      2,
      3,
      10,
      0,
      -1,
      1,
      4,
      5,
      6,
      7,
      8,
      9,
      11,
      12,
      13,
      14,
      15,
      16,
      17,
      18,
      19
   ],
   "participant_id" : [
      {
         "gaia_id" : "104323452778803782544"
      }
   ],
   "request_header" : {
      "request_header" : true,
      "client_identifier" : {
         "resource" : "lcsw_hangouts_CEDE12C7",
         "client_id" : "D2617B211AD8FD18"
      },
      "client_version" : {
         "major_version" : "babel-chat.frontend_20191215.07_p0",
         "version" : 1576448357,
         "client_id" : 6,
         "build_type" : 3
      },
      "language_code" : "hu"
   }
}
```


## License

If you happen to find a vulnerability using this tool and are rewarded with bounty, don't forget to buy me a beer :)

