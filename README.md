Die::Ception
------------

An attempt at crafting a perl function that would act like the built-in
`die`, but through several layers of callers, up to a point in the call
stack that matches a previously specified package name.

The proposed interface is:

    die_until_package("My::Caller::Package", $error_message);
