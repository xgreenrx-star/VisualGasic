let counter = 0;

function updateLabel() {
    counter++;
    lblTime.innerText = counter.toString();
}

setInterval(updateLabel, 1000);