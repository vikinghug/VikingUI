#!/usr/bin/env node

var runCommand = require('run-command');

// Environment Variables!
var dotenv = require('dotenv');
dotenv.load()

console.log(">> STARTING SERVER WITH REPL");

runCommand("coffee", ['app.coffee']);

