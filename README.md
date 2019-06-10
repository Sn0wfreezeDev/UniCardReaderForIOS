# Uni card reader for iOS 

This is a prototype project which makes it possible to scan your Uni card. In many European countries Uni cards are based on NFC and mifare. With iOS 13 Apple allowed developers to read the NFC MiFare standard and send commands to MiFare chips. 
This allowed me to create this basic App which reads out the Value of your uni card and the amount of the last transaction. 
This may not work with every card as they could differ. I have only tested it for "Technische Universität Darmstadt" yet. 

A lot of code is based on Jakob Wenzel's work in "Mensa Guthaben" -> https://github.com/jakobwenzel/MensaGuthaben 

## Disclaimer 
This code is based on Apple's sample code "NFCTagReader" 