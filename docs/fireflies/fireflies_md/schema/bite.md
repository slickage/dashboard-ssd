# API Documentation

_Source_: https://docs.fireflies.ai/schema/bite

[Skip to main content](#content-area)

[Fireflies home page![light logo](https://mintcdn.com/firefliesai/1yZ69Sj9FG7Gc0Ag/logo/light.svg?fit=max&auto=format&n=1yZ69Sj9FG7Gc0Ag&q=85&s=89d57b6f64984918e600fab4b327d867)![dark logo](https://mintcdn.com/firefliesai/1yZ69Sj9FG7Gc0Ag/logo/dark.svg?fit=max&auto=format&n=1yZ69Sj9FG7Gc0Ag&q=85&s=46855320026ba559f9e81763bda4d1eb)](https://fireflies.ai)

Search...

⌘K

Search...

Navigation

Schema

Bite

##### Getting Started

- [Introduction](/getting-started/introduction)
- [Quickstart](/getting-started/quickstart)
- [Chat with Fireflies AI Assistant](/getting-started/ask-docs)
- [Join the Developer Program](/getting-started/developer-program)
- [MCP Server Configuration](/getting-started/mcp-configuration)
- [LLM-based Development](/getting-started/llm-development)
- [What's New](/getting-started/whats-new)

##### Fundamentals

- [General concepts](/fundamentals/concepts)
- [Limits](/fundamentals/limits)
- [Errors](/fundamentals/errors)
- [Authorization](/fundamentals/authorization)
- [Introspection](/fundamentals/introspection)
- [Super Admin](/fundamentals/super-admin)

##### Examples

- [Overview](/examples/overview)
- [Basic](/examples/basic)
- [Advanced](/examples/advanced)

##### GraphQL API

- Query
- Mutation
- [Webhooks](/graphql-api/webhooks)

##### Realtime API

- [Overview](/realtime-api/overview)
- [Getting Started](/realtime-api/getting-started)
- [Event Schema](/realtime-api/event-schema)

##### Schema

- [ActiveMeeting](/schema/active-meeting)
- [AIFilter](/schema/aifilter)
- [Analytics](/schema/analytics)
- [AI Apps](/schema/apps)
- [App Output](/schema/app-output)
- [AudioUploadStatus](/schema/audio-upload-status)
- [Bite](/schema/bite)
- [Channel](/schema/channel)
- [MeetingAnalytics](/schema/meeting-analytics)
- [MeetingAttendee](/schema/meeting-attendee)
- [MeetingInfo](/schema/meeting-info)
- [Sentiments](/schema/sentiments)
- [Sentence](/schema/sentence)
- [Summary](/schema/summary)
- [SummarySection](/schema/summary-section)
- [Speaker](/schema/speaker)
- [Transcript](/schema/transcript)
- [User](/schema/user)
- [User Groups](/schema/user-groups)
- [User Group Member](/schema/user-group-member)
- Input

##### Miscellaneous

- [Language codes](/miscellaneous/language-codes)
- [Error codes](/miscellaneous/error-codes)

##### Additional Info

- [Deprecated](/additional-info/deprecated)
- [Changelog](/additional-info/change-log)

On this page

- [Additional Resources](#additional-resources)

[​](#param-id)

id

String

A unique identifier for the Bite

[​](#param-transcript-id)

transcript\_id

String

A unique identifier for the transcript the Bite is associated to

[​](#param-start-time)

start\_time

String

Start time for the Bite

[​](#param-end-time)

end\_time

String

End time for the Bite

[​](#param-name)

name

String

A string representing the title of the Bite

[​](#param-thumbnail)

thumbnail

String

URL of the Bite’s thumbnail image

[​](#param-preview)

preview

String

URL to a short preview video of the Bite

[​](#param-status)

status

String

Current processing status of the Bite. Acceptable values include ‘pending’, ‘processing’, ‘ready’,
and ‘error’

[​](#param-summary)

summary

String

An AI-generated summary describing the content of the Bite

[​](#param-user-id)

userId

String

Identifier of the user who created the Bite

[​](#param-summary-status)

summary\_status

String

Status of the AI summary generation process

[​](#param-media-type)

media\_type

String

Type of the Bite, either ‘video’ or ‘audio’

[​](#param-privacies)

privacies

[BitePrivacy]

Array specifying the visibility of the Bite. Possible values are `public`, `team`, and
`participants`. For example, `["team", "participants"]` indicates visibility to both team members
and participants, while `["public"]` allows anyone to access the bite through its link

[​](#param-created-at)

created\_at

String

The date when this Bite was created

[​](#param-user)

user

BiteUser

Object representing the user who created the Bite, including relevant user details

Show properties

[​](#param-name-1)

name

String

required

Name associated with the User

[​](#param-id-1)

id

String

required

ID of the User

[​](#param-first-name)

first\_name

String

First name of the User

[​](#param-last-name)

last\_name

String

Last name of the User

[​](#param-picture)

picture

String

Picture associated with the User

[​](#param-sources)

sources

[MediaSource]

Array of MediaSource objects for the Bite

Show properties

[​](#param-src)

src

String

required

Source of the media

[​](#param-type)

type

String

Type of the media

[​](#param-captions)

captions

[BiteCaption]

Array of Object describing text captions associated with the Bite

Show properties

[​](#param-index)

index

String

required

Index

[​](#param-speaker-id)

speaker\_id

String

required

SpeakerId associated with the caption object

[​](#param-text)

text

String

required

Text associated with the caption

[​](#param-speaker-name)

speaker\_name

String

required

Name of the speaker associated with this caption

[​](#param-start-time-1)

start\_time

String

required

Start time for the caption

[​](#param-end-time-1)

end\_time

String

required

End time for the caption

[​](#param-created-from)

created\_from

BiteOrigin

Object describing the origin of the Bite with the following properties

Show properties

[​](#param-id-2)

id

String

required

Unique identifier

[​](#param-name-2)

name

String

required

Name of the origin source

[​](#param-type-1)

type

String

required

Type of the original source, e.g., ‘meeting’

[​](#param-duration)

duration

String

Length of the original source in seconds

## [​](#additional-resources) Additional Resources

[## Transcript

Schema for Transcript](/schema/transcript)[## Create Bite

Use the API to create bites from your transcripts](/graphql-api/mutation/create-bite)

Was this page helpful?

YesNo

[Suggest edits](https://github.com/firefliesai/public-api-ff/edit/master/docs/schema/bite.mdx)[Raise issue](https://github.com/firefliesai/public-api-ff/issues/new?title=Issue on docs&body=Path: /schema/bite)

[AudioUploadStatus](/schema/audio-upload-status)[Channel](/schema/channel)

⌘I