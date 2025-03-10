# Generate/check/update a .h file to reflect the values of Makefile
# variables
#
# Example usage (by default, check-conf-h will consider all CFG_*
# and _CFG_* variables plus PLATFORM_*):
#
# path/to/conf.h: FORCE
#	$(call check-conf-h)
#
# Or, to include only the variables with the given prefix(es):
#
# path/to/crypto_config.h: FORCE
#	$(call check-conf-h,CFG_CRYPTO_ CRYPTO_)

# JDZ: echo -n not understood by macOS echo built-in, replace with printf
define check-conf-h
	$(Q)set -e;						\
	$(CMD_ECHO_SILENT) '  CHK     $@';			\
	cnf='$(strip $(foreach var,				\
		$(call cfg-vars-by-prefix,$1),			\
		$(call cfg-make-define,$(var))))';		\
	guard="_CONFIG_H_";					\
	mkdir -p $(dir $@);					\
	echo "#ifndef $${guard}" >$@.tmp;			\
	echo "#define $${guard}" >>$@.tmp;			\
	echo  "#include<$(PLATFORM).h>" >>$@.tmp;	\
	printf "$${cnf}" | sed 's/_nl_ */\n/g' >>$@.tmp;	\
	echo "#endif" >>$@.tmp;					\
	$(call mv-if-changed,$@.tmp,$@)
endef

define check-conf-mk
	$(Q)set -e;						\
	$(CMD_ECHO_SILENT) '  CHK     $@';			\
	cnf='$(strip $(foreach var,				\
		$(call cfg-vars-by-prefix,CFG_),		\
		$(strip $(var)=$($(var))_nl_)))';		\
	mkdir -p $(dir $@);					\
	echo "# auto-generated AW SPL configuration file" >$@.tmp; \
	echo "ARCH=${ARCH}" >>$@.tmp;				\
	echo "PLATFORM=${PLATFORM}" >>$@.tmp;			\
	printf "$${cnf}" | sed 's/_nl_ */\n/g' >>$@.tmp;	\
	$(call mv-if-changed,$@.tmp,$@)
endef


# Rename $1 to $2 only if file content differs. Otherwise just delete $1.
define mv-if-changed
	if [ -r $2 ] && cmp -s $2 $1; then			\
		rm -f $1;					\
	else							\
		$(CMD_ECHO_SILENT) '  UPD     $2';		\
		mv $1 $2;					\
	fi
endef

define cfg-vars-by-prefix
	$(strip $(if $(1),$(call _cfg-vars-by-prefix,$(1)),
			  $(call _cfg-vars-by-prefix,CFG_ _CFG_ PLATFORM_)))
endef

define _cfg-vars-by-prefix
	$(sort $(foreach prefix,$(1),$(filter $(prefix)%,$(.VARIABLES))))
endef

# Convert a makefile variable to a #define
# <undefined>, n => <undefined>
# y              => 1
# <other value>  => <other value>
define cfg-make-define
	$(strip $(if $(filter y,$($1)),
		     #define $1 1_nl_,
		     $(if $(filter xn x,x$($1)),
			  /* $1 is not set */_nl_,
			  #define $1 $($1)_nl_)))
endef

# Returns 'y' if at least one variable is 'y', empty otherwise
# Example:
# FOO_OR_BAR := $(call cfg-one-enabled, FOO BAR)
cfg-one-enabled = $(if $(filter y, $(foreach var,$(1),$($(var)))),y,)

# Returns 'y' if all variables are 'y', empty otherwise
# Example:
# FOO_AND_BAR := $(call cfg-all-enabled, FOO BAR)
cfg-all-enabled =                                                             \
    $(strip                                                                   \
        $(if $(1),                                                            \
            $(if $(filter y,$($(firstword $(1)))),                            \
                $(call cfg-all-enabled,$(filter-out $(firstword $(1)),$(1))), \
             ),                                                               \
            y                                                                 \
         )                                                                    \
     )

# Disable a configuration variable if some dependency is disabled
# Example:
# $(eval $(call cfg-depends-all,FOO,BAR BAZ))
# Will clear FOO if it is initially 'y' and BAR or BAZ are not 'y'
cfg-depends-all =                                                           \
    $(strip                                                                 \
        $(if $(filter y, $($(1))),                                          \
            $(if $(call cfg-all-enabled,$(2)),                              \
                ,                                                           \
                $(warning Warning: Disabling $(1) [requires $(strip $(2))]) \
                    override $(1) :=                                        \
             )                                                              \
         )                                                                  \
     )

# Disable a configuration variable if all dependencies are disabled
# Example:
# $(eval $(call cfg-depends-one,FOO,BAR BAZ))
# Will clear FOO if it is initially 'y' and both BAR and BAZ are not 'y'
cfg-depends-one =                                                                    \
    $(strip                                                                          \
        $(if $(filter y, $($(1))),                                                   \
            $(if $(call cfg-one-enabled,$(2)),                                       \
                ,                                                                    \
                $(warning Warning: Disabling $(1) [requires (one of) $(strip $(2))]) \
                    override $(1) :=                                                 \
             )                                                                       \
         )                                                                           \
     )


# Enable all depend variables
# Example:
# $(eval $(call cfg-enable-all-depends,FOO,BAR BAZ))
# Will enable BAR and BAZ if FOO is initially 'y'
cfg-enable-all-depends =                                                                   \
    $(strip                                                                                \
        $(if $(2),                                                                         \
            $(if $(filter y, $($(1))),                                                     \
                $(if $(filter y,$($(firstword $(2)))),                                     \
                    ,                                                                      \
                    $(warning Warning: Enabling $(firstword $(2)) [required by $(1)])      \
                        $(eval override $(firstword $(2)) := y)                            \
                 )                                                                         \
                 $(call cfg-enable-all-depends,$(1),$(filter-out $(firstword $(2)),$(2))), \
             )                                                                             \
             ,                                                                             \
        )                                                                                  \
     )

# Set a variable or error out if it was previously set to a different value
# The reason message (3rd parameter) is optional
# Example:
# $(call force,CFG_FOO,foo,required by CFG_BAR)
define force
$(eval $(call _force,$(1),$(2),$(3)))
endef

define _force
ifdef $(1)
ifneq ($($(1)),$(2))
ifneq (,$(3))
_reason := $$(_empty) [$(3)]
endif
$$(error $(1) is set to '$($(1))' (from $(origin $(1))) but its value must be '$(2)'$$(_reason))
endif
endif
$(1) := $(2)
endef
