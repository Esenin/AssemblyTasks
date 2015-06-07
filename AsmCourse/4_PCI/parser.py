# coding=utf-8
import os
import re


def main():
    if not os.path.isdir(os.getcwd() + "/ROOT"):
        os.mkdir("ROOT")
    os.chdir(os.getcwd() + "/ROOT")
    root_dir = os.getcwd()

    db_filename = '../pci.csv'
    print "open ", db_filename
    pci_db = open(db_filename)  # www.pcidatabase.com/reports.php?type=csv

    p = re.compile("0x([\dA-F]{4})", re.IGNORECASE)
    done_counter = 0
    incorrect_counter = 0
    max_line_len = 0
    longest_line = "$"
    print "read first line from db"
    line = "temp"
    while line:
        line = pci_db.readline()
        if len(line) <= 23:
            print "(i) too short line: ", line
            incorrect_counter += 1
            continue
        os.chdir(root_dir)
        id_list = re.findall(p, line)

        if len(id_list) < 2:
            print "(i) incorrect line was ignored: ", line
            incorrect_counter += 1
            continue

        suffix_path = id_list[0].upper() + id_list[1].upper()
        if len(suffix_path) != 8:
            print "(i) incorrect line was ignored: ", line
            incorrect_counter += 1
            continue

        for i in range(0, 8, 2):
            ddir = suffix_path[i] + suffix_path[i + 1]
            if not os.path.isdir(os.getcwd() + "/" + ddir):
                os.mkdir(ddir)
            os.chdir(os.getcwd() + "/" + ddir)

        line = line[18: -1] + "$"
        while not(line[0].isdigit() or line[0].isalpha()):
            line = line[1:]

        slen = len(line)
        if slen > max_line_len:
            max_line_len = slen
            longest_line = line

        adata = open("data", "w")
        adata.write(line)
        adata.close()
        done_counter += 1

    pci_db.close()
    total = done_counter + incorrect_counter
    print "close database ", db_filename
    print "Done ", done_counter, " devices. Incorrect ", incorrect_counter, "lines. Total:", total
    print "Processed correct lines: ", (done_counter / (total + 0.0)), " %"
    print "Longest line has", max_line_len, " chars"
    print "Longest line is:\n", longest_line
    print "exit.\n"
    
main()