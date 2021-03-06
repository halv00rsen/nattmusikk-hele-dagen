# User to create for running this application
USER = "nattmusikk-hele-dagen"

# Run/deploy nattmusikk-hele-dagen
.PHONY: run
run: settings.yaml settings_slackbot.yaml .installed_requirements
	venv/bin/python slackbot/rtmbot.py -c settings_slackbot.yaml

.PHONY: warn-if-on
warn-if-on: settings.yaml settings_slackbot.yaml .installed_requirements
	venv/bin/python warn-if-on.py

# Variations for running as the dedicated user (preferable, so you can
# reduce potential damage caused by security breaches).
.PHONY: user-run
user-run: user
	sudo -u "$(USER)" venv/bin/python slackbot/rtmbot.py -c settings_slackbot.yaml

.PHONY: user-warn-if-on
user-warn-if-on: settings.yaml settings_slackbot.yaml .installed_requirements
	sudo -u "$(USER)" venv/bin/python warn-if-on.py

# Configuration files, can be generated through helpful user interface
settings.yaml settings_slackbot.yaml: | .installed_requirements
	venv/bin/python generate_settings_file.py "$@"

# Unit files, used for defining services that start automatically
UPSTART_JOBFILE = nattmusikk-hele-dagen.conf
$(UPSTART_JOBFILE) : templates/$(UPSTART_JOBFILE) | .installed_requirements
	venv/bin/python generate_unit_file.py upstart "$@"

SYSTEMD_UNITFILE = nattmusikk-hele-dagen.service
$(SYSTEMD_UNITFILE) : templates/$(SYSTEMD_UNITFILE) | .installed_requirements
	venv/bin/python generate_unit_file.py systemd "$@"

# Deploying unit/job files, must be run as sudo
# The upstart job file
/etc/init/$(UPSTART_JOBFILE): $(UPSTART_JOBFILE)
	cp "$<" "$@"

.PHONY: deploy-upstart
deploy-upstart: /etc/init/$(UPSTART_JOBFILE)

# The SystemD unit file
/etc/systemd/system/$(SYSTEMD_UNITFILE): $(SYSTEMD_UNITFILE)
	cp "$<" "$@"

.PHONY: deploy-systemd
deploy-systemd: /etc/systemd/system/$(SYSTEMD_UNITFILE)
	systemctl enable $(SYSTEMD_UNITFILE)

# Virtual environment
venv:
	virtualenv -p python3 venv

# This file is used just to make sure we adopt to changes in 
# requirements.txt. Whenever they change, we install the packages
# again and touch this file, so its modified date is set to now.
.installed_requirements: requirements.txt slackbot/requirements.txt | venv
	. venv/bin/activate && pip install -r requirements.txt
	touch .installed_requirements

# Create USER if it doesn't exist yet
.PHONY: user
user:
	@echo "sudo is potentially needed to create a new user on this system."
	id -u $(USER) > /dev/null 2>&1 || (sudo adduser --system --no-create-home --group --disabled-login $(USER) && sudo usermod -a -G liquidsoap $(USER))

# Make the application ready for deployment
.PHONY: setup
setup: .installed_requirements settings.yaml settings_slackbot.yaml user

# Remove any local user-files from the folder
.PHONY: wipe
wipe:
	rm -rf venv settings.yaml settings_slackbot.yaml .installed_requirements nattmusikk-hele-dagen.conf nattmusikk-hele-dagen.service


