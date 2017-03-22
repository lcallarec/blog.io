---
layout: post
title: Write a custom USB client
subtitle: With Wireshark, Luxafor & Vala
tags:
  - USB
  - Luxafor
  - Vala
  - Wireshark
---

# Purposes

I'm sometimes using a __[Luxafor](http://www.luxafor.fr/products/)__ device at work, and I finally bought one for the fun - because I guess that there's something interesting to do with it. Luxafor only provides clients for _Macos_ and _Windows_, so I could write a **Luxafor** client for _Linux_, couldn't I ?

I knew that there was, at that time, at least two libraries, written for __[nodejs](https://github.com/iamthefox/luxafor)__ and for __[python](https://github.com/vmitchell85/luxafor-python)__ that could do the trick, but that's not fun, the challenge is elsewhere :p

> It doesn't look so hard, it's basically binary data sent over an USB device

The plan is all about :

* capturing binary data sent from the official Luxafor client to the physical device
* analyzing the client -> device communication to be able to reproduce with our own-baked client.

# Capture the USB traffic

There's no client for Linux, so I have to capture USB packets from a _Window_ or from a _MacOs_ installation. Sadly, capturing USB communication is far too complex on a recent _MacOs_ and I lost 2 hours trying it inside a physical _Windows_ OS.

That's why I decided to have a _VirtualBox'ed Windows_ guest OS running inside a _Linux_ host. Best of both worlds: I can install the Luxafor client on _Windows_ and easily capture the USB on the _Linux_ host thanks to the USB forwarding capacity of *VirtualBox*.

## Install required pieces of software

{% highlight bash %}
$ sudo install wireshark virtualbox
{% endhighlight %}

*Pre-requisites that won't be explained :*

* Install a Windows Virtual machine with VirtualBox
* Install the [Luxafor client for Windows](http://www.luxafor.fr/download/)

## Forward USB device from host to guest

* Make sure to install the extension pack for the [host](https://www.virtualbox.org/wiki/Downloads) and the Guest add-ons for the guest
* Add your user to the virtualbox group
{% highlight bash %}
$ sudo adduser $(whoami) vboxusers
{% endhighlight %}
* Make sure to logout the current session for this to apply, before running _VirtualBox_. Else, the hypervisor won't be able to forward USB device traffic.

* Open box settings, open the *USB* tab, activate USB 2.0 (EHCI) and add the device :

![]({{ site.url }}/assets/2017-03-22/virtualbox-usb-forwarding.png)

* Once done, start the VM and launch the Luxafor client.

## Register usbmon Kernel module & start Wireshark

The following command will register the USBmonitor module to extend the Linux Kernel :

{% highlight bash %}
$ sudo modprobe usbmon
{% endhighlight %}

Then start Wireshark as su :
{% highlight bash %}
$ sudo wireshark
{% endhighlight %}

## Find in which monitor the Luxafor is plugged

![interfaces]({{ site.url }}/assets/2017-03-22/wireshark-ready.png)

When Wireshark starts, you'll see the live traffic on each interfaces that can be sniffed by the tool. The __usbmon2__ traffic pikes matches exactly the time when I changed the color of the device from the Windows client :

![interfaces]({{ site.url }}/assets/2017-03-22/wireshark-usbmon-list.png)

### Capture Live USB traffic

__Activate the Luxafor color RED__

Double-click on usbmon2.

__Change Luxafor color and analyze the payload__

Change the Luxafor color to blue ; when color change, _Wireshark_ has captured you packets :

![Sniff]({{ site.url }}/assets/2017-03-22/wireshark-capture-blue.png)

The most important information is the *URB_INTERRUPT out*  packet sent from host to USB device. The leftover capture data are the actual payload that has been sent to the USB device :

{% highlight R %}
01 ff 00 00 ff 00 00 00
{% endhighlight %}

Bingo !

* The packet sent is eight 8-bits data long
* There's one `ff` after two `00`. My guesses : the first `00` stand for *Red* channel (`0x00`), the second for the Green channel (`0x00`), and the last one for the Blue channel (`0xff`). It seems too obvious.
* Simple test : what happens if I set the color to yellow ? If I'm guessing right, Luxafor should sniff these hexadecimal values like :

{% highlight R %}
01 ff fa fa 00 00 00 00
{% endhighlight %}

Let's try (... but the Windows *Luxafor* client doesn't allow accurate settings).

![Sniff again]({{ site.url }}/assets/2017-03-22/luxafor-client-yellow.png)

Guess what :

![Sniff again]({{ site.url }}/assets/2017-03-22/wireshark-capture-yellow.png)

Lucky man :

{% highlight R %}
01 ff fa fa 00 00 00 00
{% endhighlight %}

## It can be concluded that...

The payload sent over the USB device is made of 8 bytes :

* first byte : unknown meaning
* second byte : unknown meaning
* third byte is for the red channel
* fourth byte is for the green channel
* fifth byte is for the red channel
* sixth byte : unknown meaning
* seventh byte : unknown meaning

## Unregister usbmon Kernel module

To close your monitoring session in a clean way, unregister the __usbmod__ module :

{% highlight bash %}
$ sudo modprobe -r usbmon
{% endhighlight %}

# Write the client

In this chapter, we'll write a __[Vala](https://wiki.gnome.org/Projects/Vala)__ program to change the __Luxafor__ color.

If you want to fully understand the next chapter, let me suggesting to read chunks of documentation from [LibUSB](http://libusb.info/). It's what I did, and I learnt that prior to connect to an USB device, I have to find its __vendorID__ and __productID__.

## Find USB vendorID / productID

Capture with `lusb` command the list of connected device - with the Luxafor un-plugged, and re-fetch the list with the Luxafor plugged to guess which one is the device you're looking for :

{% highlight bash %}
$ lsusb > unplugged
# Plug your device
$ lsusb > plugged
# Don't remove any USB device a that time :p
$ diff plugged unplugged
1d0 < Bus 002 Device 008: ID 04d8:f372 Microchip Technology, Inc.
{% endhighlight %}

What's left is the Luxafor device. `04d8:f372` are respectively the __vendorID__ and the __productID__ we're looking for.

## Install Vala and other dependencies

On an apt package manager based system, it's really straight forward :

{% highlight bash %}
$ sudo apt-get install vala libusb-1.0-0 libusb-1.0-0-dev libusb-dev
{% endhighlight %}

## Vala code

* The color we want to send to the device is a pure white `0xff 0xff 0xff`
* We have to claim the interface of the device uniquely identified by __vendorID__ `0x04d8` and __productID__ `0xf372`

__main.vala__

{% highlight vala %}

int main(string[] args)
{
	LibUSB.Context context;
	LibUSB.Device[] devices;
	LibUSB.DeviceHandle handle;
	LibUSB.Device? luxafor = null;

	LibUSB.Context.init(out context);
	context.get_device_list (out devices);

	int i = 0;
	while (devices[i] != null)
	{
		var dev = devices[i];
		LibUSB.DeviceDescriptor desc = LibUSB.DeviceDescriptor (dev);
		if (desc.idVendor == 0x04d8 && desc.idProduct == 0xf372)
		{
			luxafor = dev;
			break;
		}
		i++;
	}		

	if (null != luxafor)
	{

		int result = luxafor.open(out handle);
		if (result != 0) {
			return 1;
		}

		handle.detach_kernel_driver(0);

		int retries = 1000;
		int claim_device_result;
		while ((claim_device_result = handle.claim_interface(0)) != 0 && retries-- > 0) {
			handle.detach_kernel_driver(0);
		}

		if (claim_device_result == 0)
		{
			int len;
			handle.bulk_transfer(1, {0x01, 0xff, 0xff, 0xff, 0xff, 0x00, 0x00, 0x00}, out len, 10);
		}
	}

	return 0;
}
{% endhighlight %}

* the device is identified by `if (desc.idVendor == 0x04d8 && desc.idProduct == 0xf372)`
* the packet will be send with this method call : `handle.bulk_transfer(1, {0x01, 0xff, 0xff, 0xff, 0xff, 0x00, 0x00, 0x00}, out len, 10);`

## Compile and run

__Compile__

{% highlight bash %}
$ valac --pkg libusb-1.0 main.vala -o usb
{% endhighlight %}

__Run__

{% highlight bash %}
$ sudo ./usb
{% endhighlight %}

# And there is light !

__Luxafor__ start and the color change immediately to white bright color, as expected !

Thanks for reading, any feedbacks or contributions via [issues](https://github.com/lcallarec/lcallarec.github.io/issues) or [pull requests](https://github.com/lcallarec/lcallarec.github.io/pulls) are welcome !
