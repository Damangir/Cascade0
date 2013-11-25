#!/usr/bin/awk -f

BEGIN {
    FS=","
    print "<table>"
}
{
gsub(/</, "\\&lt;")
gsub(/>/, "\\&gt;")
gsub(/&/, "\\&amp;")
gsub(/"/, "")
}

NR == 1{
    if (header){
        print "<thead>"
        print " <tr>"
        for(f = 1; f <= NF; f++)  {
            printf "  <td>%s</td>\n", $f
        }
        print " </tr>"
        print "</thead>"
    }
    print "<tbody>"
}

{
    if (NR == 1 && header) {
        next
    }
    print " <tr>"
    for(f = 1; f <= NF; f++)  {
        printf "  <td>%s</td>\n", $f
    }       
    print " </tr>"
}       
 
END {
    print "</tbody>"
    print "</table>"
}