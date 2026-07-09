using System;
using System.Windows.Forms;

Application.EnableVisualStyles();
Application.SetCompatibleTextRenderingDefault(false);
Application.Run(new MainForm());

public class MainForm : Form
{
    private Timer timer1;
    private Label lblTime;
    private int counter = 0;

    public MainForm()
    {
        InitializeComponents();
        SetupTimer();
    }

    private void InitializeComponents()
    {
        this.Text = "Timer Counter";
        this.Width = 300;
        this.Height = 200;

        lblTime = new Label();
        lblTime.Text = "Count: 0";
        lblTime.Font = new System.Drawing.Font("Arial", 16, System.Drawing.FontStyle.Bold);
        lblTime.AutoSize = true;
        lblTime.Location = new System.Drawing.Point(80, 70);
        this.Controls.Add(lblTime);
    }

    private void SetupTimer()
    {
        timer1 = new Timer();
        timer1.Interval = 1000;
        timer1.Tick += Timer1_Tick;
        timer1.Start();
    }

    private void Timer1_Tick(object sender, EventArgs e)
    {
        counter++;
        lblTime.Text = "Count: " + counter.ToString();
        Console.WriteLine("Counter updated: " + counter);
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing)
        {
            timer1?.Stop();
            timer1?.Dispose();
        }
        base.Dispose(disposing);
    }
}