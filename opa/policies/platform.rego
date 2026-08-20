package platform.authz

default allow = false

allow {
  input.subject.roles[_] == "platform_admin"
}

allow {
  input.action == "read"
  input.resource.domain == "maintenance"
  input.subject.roles[_] == "maintenance_analyst"
  input.subject.areas[_] == input.resource.area
}

allow {
  input.action == "read"
  input.resource.kind == "application"
  input.subject.roles[_] == "viewer"
}
