# Analytics query - Fireflies.ai API Documentation

_Source_: https://docs.fireflies.ai/graphql-api/query/analytics

[Skip to main content](#content-area)

[Fireflies home page![light logo](https://mintcdn.com/firefliesai/1yZ69Sj9FG7Gc0Ag/logo/light.svg?fit=max&auto=format&n=1yZ69Sj9FG7Gc0Ag&q=85&s=89d57b6f64984918e600fab4b327d867)![dark logo](https://mintcdn.com/firefliesai/1yZ69Sj9FG7Gc0Ag/logo/dark.svg?fit=max&auto=format&n=1yZ69Sj9FG7Gc0Ag&q=85&s=46855320026ba559f9e81763bda4d1eb)](https://fireflies.ai)

Search...

⌘K

Search...

Navigation

Query

Analytics

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

  - [Active Meetings](/graphql-api/query/active-meetings)
  - [Analytics](/graphql-api/query/analytics)
  - [AI Apps](/graphql-api/query/apps)
  - [User](/graphql-api/query/user)
  - [Users](/graphql-api/query/users)
  - [User Groups](/graphql-api/query/user-groups)
  - [Transcript](/graphql-api/query/transcript)
  - [Transcripts](/graphql-api/query/transcripts)
  - [Bite](/graphql-api/query/bite)
  - [Bites](/graphql-api/query/bites)
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

curl

javascript

python

java

Copy

Ask AI

```
curl -X POST \
-H "Content-Type: application/json" \
-H "Authorization: Bearer your\_api\_key" \
--data '{ "query": "query Analytics($startTime: String, $endTime: String) { analytics(start\_time: $startTime, end\_time: $endTime) { team { conversation { average\_filler\_words } } } }", "variables": { "startTime": "2024-01-01T00:00:00Z", "endTime": "2024-01-31T23:59:59Z" } }' \
https://api.fireflies.ai/graphql
```

Response

Copy

Ask AI

```
{
"data": {
"analytics": {
"team": {
"conversation": {
"average\_filler\_words": 15
}
}
}
}
}
```

## [​](#overview) Overview

The analytics query fetches detailed conversation and meeting metrics for teams and users across a specified date range.

## [​](#arguments) Arguments

[​](#param-start-time)

start\_time

String

The `start_time` parameter filters results starting from a specific datetime (ISO 8601 format).

[​](#param-end-time)

end\_time

String

The `end_time` parameter filters results up to a specific datetime (ISO 8601 format).

## [​](#schema) Schema

Fields available to the [Analytics](/schema/analytics) query.

## [​](#usage-example) Usage Example

Copy

Ask AI

```
query Analytics($startTime: String, $endTime: String) {
analytics(start\_time: $startTime, end\_time: $endTime) {
team {
conversation {
average\_filler\_words
average\_filler\_words\_diff\_pct
average\_monologues\_count
average\_monologues\_count\_diff\_pct
average\_questions
average\_questions\_diff\_pct
average\_sentiments {
negative\_pct
neutral\_pct
positive\_pct
}
average\_silence\_duration
average\_silence\_duration\_diff\_pct
average\_talk\_listen\_ratio
average\_words\_per\_minute
longest\_monologue\_duration\_sec
longest\_monologue\_duration\_diff\_pct
total\_filler\_words
total\_filler\_words\_diff\_pct
total\_meeting\_notes\_count
total\_meetings\_count
total\_monologues\_count
total\_monologues\_diff\_pct
teammates\_count
total\_questions
total\_questions\_diff\_pct
total\_silence\_duration
total\_silence\_duration\_diff\_pct
}
meeting {
count
count\_diff\_pct
duration
duration\_diff\_pct
average\_count
average\_count\_diff\_pct
average\_duration
average\_duration\_diff\_pct
}
}
users {
user\_id
user\_name
user\_email
conversation {
talk\_listen\_pct
talk\_listen\_ratio
total\_silence\_duration
total\_silence\_duration\_compare\_to
total\_silence\_pct
total\_silence\_ratio
total\_speak\_duration
total\_speak\_duration\_with\_user
total\_word\_count
user\_filler\_words
user\_filler\_words\_compare\_to
user\_filler\_words\_diff\_pct
user\_longest\_monologue\_sec
user\_longest\_monologue\_compare\_to
user\_longest\_monologue\_diff\_pct
user\_monologues\_count
user\_monologues\_count\_compare\_to
user\_monologues\_count\_diff\_pct
user\_questions
user\_questions\_compare\_to
user\_questions\_diff\_pct
user\_speak\_duration
user\_word\_count
user\_words\_per\_minute
user\_words\_per\_minute\_compare\_to
user\_words\_per\_minute\_diff\_pct
}
meeting {
count
count\_diff
count\_diff\_compared\_to
count\_diff\_pct
duration
duration\_diff
duration\_diff\_compared\_to
duration\_diff\_pct
}
}
}
}
```

curl

javascript

python

java

Copy

Ask AI

```
curl -X POST \
-H "Content-Type: application/json" \
-H "Authorization: Bearer your\_api\_key" \
--data '{ "query": "query Analytics($startTime: String, $endTime: String) { analytics(start\_time: $startTime, end\_time: $endTime) { team { conversation { average\_filler\_words } } } }", "variables": { "startTime": "2024-01-01T00:00:00Z", "endTime": "2024-01-31T23:59:59Z" } }' \
https://api.fireflies.ai/graphql
```

Response

Copy

Ask AI

```
{
"data": {
"analytics": {
"team": {
"conversation": {
"average\_filler\_words": 15
}
}
}
}
}
```

## [​](#error-codes) Error Codes

List of possible error codes that may be returned by the `analytics` query. Full list of error codes can be found [here](/miscellaneous/error-codes).


paid\_required (business\_or\_higher)

You need to be on a Business or higher plan to query analytics.



require\_elevated\_privilege

The user does not have admin privileges to view analytics for team.

## [​](#additional-resources) Additional Resources

[## Transcripts

Querying list of transcripts](/graphql-api/query/transcripts)[## Users

Querying list of users](/graphql-api/query/users)

Was this page helpful?

YesNo

[Suggest edits](https://github.com/firefliesai/public-api-ff/edit/master/docs/graphql-api/query/analytics.mdx)[Raise issue](https://github.com/firefliesai/public-api-ff/issues/new?title=Issue on docs&body=Path: /graphql-api/query/analytics)

[Active Meetings](/graphql-api/query/active-meetings)[AI Apps](/graphql-api/query/apps)

⌘I