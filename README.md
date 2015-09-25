# ECS Zonar

This is a simple Route53 registration program for ECS tasks.
It's probably the wrong tool for the job, but it's still kinda neat and can be
used to bootstrap membership discovery, as a really bad form of service
discovery, or as a lesson in what not to do.

# Usage

In order to use it, simply add the environment variable `_ECS_R53_DNS` to a
task's container with the value of the dns entry you would like to to fill.
The dns entry should be a subdomain of a domain you've got in Route53, but the
specific subdomain does not have to be exist and will be created if it does
not.

For example, if you have a Route53 zone named `example.com` and you have a task
with the environment variable `_ECS_R53_DNS=foo.example.com`, the A record
Route53 value for `foo.example.com` will be set to all ips of EC2 Instances
running said task.

If you need a single task to have multiple DNS entries, you can add additional
numbered variables, such as `_ECS_R53_DNS1` and so on.

# How consistent is this?

**Eventually**, aka as consistent as DNS. I like to think that it has roughly
the consistency of uncooked cookie dough &mdash; it's tempting, but ultimately
will make you sick.

# TODO

1. Do something more sane than overloading an environment variable for figuring
   out the mapping.
2. Register SRV records to capture dynamic ports?
3. Allow configurable TTL per task maybe?
4. Something something Route53 healthchecks something something bad idea.
5. Tests

# That name is bad

Thanks.

# License

Public domain.

This isn't a restriction or anything, but if you do make changes and want to
contribute them back that would be awesome.
