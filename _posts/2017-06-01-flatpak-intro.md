---
layout: post
title: Flatpak, 7 days after
subtitle: Feedback, feeling & rock'n'roll
image: assets/flatpak/flatpak-header.png
tags:
  - Flatpak
  - Gnome
  - Continuous integration
  - Travis
  - Docker
  - Feedback
---

# ... and there is Flatpak

I won't loose my time in trying to explain what is __[Flatpak](http://flatpak.org/)__. What's better than the official baseline ?

> [Flatpak] is the next-generation technology for building and installing desktop applications.
  It has the power to revolutionize the Linux desktop ecosystem.

__[Wikipedia](https://en.wikipedia.org/wiki/Flatpak)__ give a more academic explaination :

> [Flatpak] is a software utility for software deployment, package management, and application virtualization for Linux desktop computer

The objective of this post is to give my feedback after having played a bit with __Flatpak__, and show you how it solved some of my problems.

# Feedbacks

Honestly, I don't like to give premature feedbacks ; they may be the most instinctive ones, but there's always a bias we've got to fight and discard.
The only thoughts I can honestly offer is that __Flatpak__ is a suite of command-line tools involving lots of concepts. Sometimes, it's a bit rough and the documentation doesn't help so much.

But when you get the gist, it works very well, in a predictive way.

# How Flatpak solved my top 4 problems

I like to code Vala or in C, and the trickiest parts with that kind of stack are :

* __Design a portable application :__ Designing an application to work on multiple OS / runtimes / Linux distributions is time consuming
* __keep the overall quality at a great level :__ In a Continuous integration workflow, the build matrix where the tests run became over complicated as compatibility / stability issues arise
* __build & distributing applications for all :__ Building & distributing the application on multiple OS / runtimes / Linux distributions requires lots of human resources (and infrastructure)

## Design a portable application

### Before Flatpak

Coding a (system) application while keeping compatibilty with a wide variery of runtimes and libraries - most of the time, it's done by using conditional FLAGS - is really pain. Wise people can choose to __statically link__ dependencies, but there's some drawbacks which make the whole sometimes not predictable.

With Flatpack, Gnome runtimes contains a wide range of libraries freezed at a known and predictable version.

But I first came to __[Flatpak](http://flatpak.org/)__ with the idea to test the build of a Vala application against different versions of Gtk3+.

Doing this without __[Flatpak](http://flatpak.org/)__ is still possible with Docker, but would require one base image per Gtk3+ version.

On a project driven by a small team, it may be a right choice to build against only one targeted Gtk3+ version and do choices about wich Gtk version range to support. And it doesn't only concern Gtk3+, but all libraries that your project depends on.

And when it's time to distribute the application on a variety of Linux distributions, things became really handy.

Flapak to the rescue : it's where Flatpak is good at. Distribute and keep up-to-date our applications without thinking about dependencies.
If they build inside a Flatpak sandbox, they'll run in it.

### After Flatpak

I created a Docker image containing some __[Flatpak](http://flatpak.org/)__ basics, like remotes gnome repositories.

{% highlight Dockerfile%}
# Flatpak-gnome
#
# AUTHOR                Laurent Callarec<l.callarec@gmail.com>
# VERSION               0.0.2
FROM ubuntu:17.04

RUN apt-get update -y

# Install base dependencies
## For add-apt-repository binary
RUN apt-get install -y software-properties-common python-software-properties build-essential

# Install flatpak
RUN add-apt-repository ppa:alexlarsson/flatpak -y
RUN apt-get update -y
RUN apt install flatpak -y

# Install remote
RUN flatpak remote-add --if-not-exists gnome https://sdk.gnome.org/gnome.flatpakrepo

# Clean
RUN apt-get clean -y && apt-get autoclean -y

CMD ["/bin/bash"]
{% endhighlight %}

Then on travis, I have this project and this file :

{% highlight yml%}
---
dist: trusty
sudo: required

language: c

services:
  - docker

before_install:
  - docker pull lcallarec/flatpak-gnome

script:
  - docker run --privileged -v $PWD:/build:rw lcallarec/flatpak-gnome /bin/bash -c "cd /build && make"

{% endhighlight %}

{% highlight yml%}
{% endhighlight %}
