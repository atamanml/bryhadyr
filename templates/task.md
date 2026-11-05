A task an agent files for work somebody will pick up within two weeks (protocol §1). Fields for `create_tasks`.

title:       Replace the polling loop in the importer with a queue      # verb + result, ≤ 120 characters
labels:      agent                                                      # + quick (≤ 15 min), waiting (needs a human), blocked (with the reason)
project:     <the project of the topic; unsure → no project (the Inbox)>
origin_url:  <PR or issue link, when there is one>
description: |
  From: <the owner's task this grew out of: <opentodo-url>/?task=<id> , or the request in one sentence>
  Context: <2–6 lines, only when the task cannot be understood without its history: why, what was tried and failed, decisions taken>
  Note: 10 - Projects/<Project>/<file>.md                               # when there is one
  Done when: <a check that can be run: "make test passes with the queue enabled">
