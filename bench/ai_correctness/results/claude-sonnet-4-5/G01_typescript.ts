function handleButtonClick(): void {
    const lblStatus = document.getElementById('lblStatus') as HTMLLabelElement;
    if (lblStatus) {
        lblStatus.textContent += '\nButton clicked at ' + new Date().toLocaleTimeString();
    }
}

const button = document.getElementById('myButton') as HTMLButtonElement;
if (button) {
    button.addEventListener('click', handleButtonClick);
}