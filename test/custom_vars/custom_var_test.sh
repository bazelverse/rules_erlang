set -ex

cat custom_vars/custom_var

# Assert the make variable resolved to *an* OTP version, not to a particular
# one. Pinning a range here (it was 2[4-6]) makes the test fail on every OTP
# released after the range was written, which says nothing about whether
# @rules_erlang//tools:erlang_vars works. An unexpanded or empty variable still
# fails this, which is what the test is actually guarding.
grep -E 'OTP_VERSION: [0-9]+\.' custom_vars/custom_var
