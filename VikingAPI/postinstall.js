#!/usr/bin/env node

var runCommand = require('run-command');

// Environment Variables!
var dotenv = require('dotenv');
dotenv.load()

runCommand("bower", ['install']);
runCommand("gulp");
