function onButtonClick(): void {
    const lblStatus: HTMLLabelElement = document.getElementById('lblStatus') as HTMLLabelElement;
    if (lblStatus) {
        lblStatus.textContent += '\nNew line added';
    } else {
        console.error('Label with id "lblStatus" not found');
    }
}