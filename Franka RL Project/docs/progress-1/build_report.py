"""Build the Progress 1 PDF from the MATLAB figure exports."""
from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_JUSTIFY, TA_LEFT, TA_RIGHT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.platypus import Image, PageBreak, Paragraph, SimpleDocTemplate, Table, TableStyle


ROOT = Path(__file__).resolve().parent
PAGE_MARGIN = 48
FRAME_PADDING = 6
CONTENT_WIDTH = A4[0] - 2 * (PAGE_MARGIN + FRAME_PADDING)
INK = colors.HexColor("#162B3A")
TEAL = colors.HexColor("#176A70")
PALE = colors.HexColor("#EDF4F5")
RULE = colors.HexColor("#D6E2E5")
styles = getSampleStyleSheet()
styles.add(ParagraphStyle("Kicker", fontName="Helvetica-Bold", fontSize=9,
                          textColor=TEAL, spaceAfter=10))
styles.add(ParagraphStyle("TitlePage", fontName="Helvetica-Bold", fontSize=25,
                          leading=28, textColor=INK, spaceAfter=12))
styles.add(ParagraphStyle("Section", fontName="Helvetica-Bold", fontSize=13,
                          leading=16, textColor=TEAL, spaceBefore=12, spaceAfter=6))
styles.add(ParagraphStyle("Text", fontName="Helvetica", fontSize=10.5, leading=15,
                          alignment=TA_JUSTIFY, textColor=INK, spaceAfter=7))
styles.add(ParagraphStyle("Cell", parent=styles["Text"], fontSize=9.2, leading=12,
                          alignment=TA_LEFT, spaceAfter=0))
styles.add(ParagraphStyle("HeaderCell", parent=styles["Cell"], fontName="Helvetica-Bold",
                          textColor=colors.white))
styles.add(ParagraphStyle("Caption", parent=styles["Cell"], alignment=TA_CENTER,
                          textColor=TEAL, spaceBefore=4, spaceAfter=10))
styles.add(ParagraphStyle("TableNote", parent=styles["Cell"], spaceBefore=6))
styles.add(ParagraphStyle("TableTitle", parent=styles["Cell"], spaceAfter=4))
styles.add(ParagraphStyle("ContentsEntry", parent=styles["Text"], alignment=TA_LEFT, spaceAfter=0))
styles.add(ParagraphStyle("ContentsPage", parent=styles["ContentsEntry"],
                          alignment=TA_RIGHT, textColor=TEAL))


def paragraph(text, style="Text"):
    return Paragraph(text, styles[style])


TABLE_ENTRIES = [
    ("table-kinematics", "Table 1. Base-to-hand forward kinematics", 2),
    ("table-observations", "Table 2. Observation entries and purposes", 3),
    ("table-reward", "Table 3. Reward terms and purposes", 3),
    ("table-work", "Table 4. Work breakdown through Progress 2", 4),
]


def table_title(index, note=""):
    key, title, _ = TABLE_ENTRIES[index]
    return paragraph(f'<a name="{key}"/>{title}{note}.', "TableTitle")


def table(rows, widths, padding=7):
    cells = [[paragraph(value, "HeaderCell" if index == 0 else "Cell")
              for value in row] for index, row in enumerate(rows)]
    widths = [CONTENT_WIDTH * width / sum(widths) for width in widths]
    result = Table(cells, colWidths=widths, hAlign="LEFT", repeatRows=1)
    result.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), TEAL),
        ("ROWBACKGROUNDS", (0, 1), (-1, -1), [PALE, colors.white]),
        ("LINEBELOW", (0, -1), (-1, -1), 0.65, RULE),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("TOPPADDING", (0, 0), (-1, -1), padding),
        ("BOTTOMPADDING", (0, 0), (-1, -1), padding),
    ]))
    return result


def pose_figure():
    poses = [
        ("matlab_panda_home.png", "A. Default home pose<br/>Self-collision detected"),
        ("matlab_panda_pose_1.png", "B. Starter ready pose<br/>Collision-free"),
        ("matlab_panda_pose_2.png", "C. Sampled task-start pose<br/>Collision-free"),
    ]
    column_width = CONTENT_WIDTH / len(poses)
    images = [Image(str(ROOT / filename), width=column_width - 8, height=136,
                    kind="proportional") for filename, _ in poses]
    captions = [paragraph(caption, "Caption") for _, caption in poses]
    result = Table([images, captions], colWidths=[column_width] * len(poses), hAlign="LEFT")
    result.setStyle(TableStyle([("ALIGN", (0, 0), (-1, 0), "CENTER"),
                                ("VALIGN", (0, 0), (-1, -1), "TOP"),
                                ("LEFTPADDING", (0, 0), (-1, -1), 4),
                                ("RIGHTPADDING", (0, 0), (-1, -1), 4)]))
    return result


def page_links(entries):
    rows = [[paragraph(f'<link href="#{key}">{label}</link>', "ContentsEntry"),
             paragraph(f'<link href="#{key}">{page}</link>', "ContentsPage")]
            for key, label, page in entries]
    result = Table(rows, colWidths=[CONTENT_WIDTH - 34, 34], hAlign="LEFT")
    result.setStyle(TableStyle([
        ("LEFTPADDING", (0, 0), (-1, -1), 0),
        ("RIGHTPADDING", (0, 0), (-1, -1), 0),
        ("TOPPADDING", (0, 0), (-1, -1), 10),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 10),
        ("LINEBELOW", (0, 0), (-1, -1), 0.5, RULE),
    ]))
    return result


def footer(canvas, document):
    edge = PAGE_MARGIN + FRAME_PADDING
    canvas.setStrokeColor(RULE)
    canvas.line(edge, 45, A4[0] - edge, 45)
    canvas.setFillColor(TEAL)
    canvas.setFont("Helvetica", 8)
    canvas.drawString(edge, 30, "MCT464  /  FALL 2026  /  PROGRESS 1")
    canvas.drawRightString(A4[0] - edge, 30, str(document.page))


story = [
    paragraph("MCT464  /  SELECTED TOPICS IN ROBOTICS &amp; AI", "Kicker"),
    paragraph("Franka Panda<br/>Moving-Target Tracking", "TitlePage"),
    paragraph("<b>Progress 1</b> &nbsp;|&nbsp; Robot setup and reinforcement learning formulation"),
    paragraph("Table of contents", "Section"),
    page_links([
        ("robot", "1. Robot setup and forward kinematics", 2),
        ("formulation", "2. Reinforcement learning formulation", 3),
        ("algorithms", "3. Chosen learning algorithms", 4),
        ("work-plan", "4. Work breakdown through Progress 2", 4),
    ]),
    paragraph("List of Figures", "Section"),
    page_links([("panda-poses", "Figure 1. Panda configurations exported directly from MATLAB", 2)]),
    paragraph("List of Tables", "Section"),
    page_links(TABLE_ENTRIES),
    PageBreak(),
    paragraph('<a name="robot"/>1. Robot setup and forward kinematics', "TitlePage"),
    paragraph("The MATLAB Robotics System Toolbox model is loaded with "
              "<font face='Courier'>loadrobot('frankaEmikaPanda')</font>. The simulated arm "
              "has seven revolute joints. Both finger coordinates are held at 0.04 m. "
              "Position is measured at the origin of the <b>panda_hand</b> frame relative "
              "to the robot base, using the translation column of its forward-kinematics transform."),
    pose_figure(),
    paragraph('<a name="panda-poses"/>Figure 1. Panda configurations exported directly from MATLAB.',
              "Caption"),
    paragraph("The toolbox default home pose serves as a forward-kinematics reference. "
              "MATLAB detects self-collision there, so task starts are sampled near the "
              "collision-free starter ready pose. The start shown uses validation seed 6029."),
    table_title(0, " (rounded to four decimals)"),
    table([
        ["Pose", "Arm joints q1 to q7 (rad)", "Hand position (m)", "Self-collision"],
        ["Default home", "0, 0, 0, -1.5708, 0, 0, 0", "(0.3595, 0, 0.6435)", "Detected"],
        ["Starter ready", "0, -0.7850, 0, -2.3560, 0, 1.5710, 0.7850",
         "(0.3070, 0, 0.5903)", "Clear"],
        ["Task start", "0.0470, -0.6876, -0.0996, -2.4321, -0.0206, 1.6376, 0.8389",
         "(0.3316, -0.0243, 0.5274)", "Clear"],
    ], [83, 207, 128, 80]),
    paragraph("Home rotation rows: [0, 0, -1]; [0.7071, -0.7071, 0]; [-0.7071, -0.7071, 0].<br/>"
              "Task-start rotation rows: [0.9910, -0.0795, -0.1077]; [-0.0750, -0.9961, 0.0455]; "
              "[-0.1109, -0.0370, -0.9931].", "TableNote"),
    PageBreak(),
    paragraph("TASK FORMULATION", "Kicker"),
    paragraph('<a name="formulation"/>2. Reinforcement learning formulation', "TitlePage"),
    paragraph("The arm tracks a straight-line target at constant velocity with speed up to "
              "0.01 m/s. The kinematic simulation advances in 0.05 s steps for up to 400 steps "
              "(20 s). The task has no obstacles or orientation constraint."),
    table_title(1),
    table([
        ["Observation entries", "Dim.", "Purpose"],
        ["Arm joint angles", "7", "Identify the arm configuration and inform safe motion near joint limits."],
        ["Target position in the base frame", "3", "Locate the current target within the workspace."],
        ["Target velocity in the base frame", "3", "Allow the policy to anticipate the next target position."],
        ["Target position minus hand position", "3", "Provide the direction and distance of the current tracking error."],
        ["Previous applied joint increments", "7", "Expose the history needed to assess changes between actions."],
        ["Remaining fraction of the episode", "1", "Represent the finite horizon and proximity to the final scoring window."],
    ], [187, 41, 270], padding=5),
    paragraph("Action and reset", "Section"),
    paragraph("The deterministic policy outputs seven joint increments in radians. Each is "
              "clipped to [-0.01, 0.01] before applying it. Reset samples a valid pose near "
              "the starter ready pose and a target initially 1 to 2 cm from the hand. The start "
              "and endpoint of the target path must lie in the workspace "
              "<b>x</b> = [0.30, 0.65], <b>y</b> = [-0.30, 0.30], "
              "<b>z</b> = [0.15, 0.60] m."),
    paragraph("Reward and termination", "Section"),
    paragraph("For tracking error e in metres, define c(e) = (50e)/(1 + 50e). The valid-step "
              "reward combines the following terms."),
    table_title(2),
    table([
        ["Term", "Purpose"],
        ["-c(e)", "Penalizes hand-to-target distance and bounds the tracking cost."],
        ["20[c(e<sub>prev</sub>) - 0.95c(e)]", "Rewards reducing the tracking cost relative to the previous step."],
        ["-0.01 sum(((a - a<sub>prev</sub>)/0.01)<super>2</super>)",
         "Discourages abrupt changes in joint increments."],
        ["-0.01 near a joint limit", "Discourages states within 0.1 rad of a limit."],
    ], [235, 263], padding=5),
    paragraph("A proposed joint-limit or self-collision violation is rejected, gives reward "
              "-250, and ends the episode as a failure. A valid episode ends at step 400 and "
              "succeeds only if every error sample in its final 100 steps is at most 0.02 m."),
    PageBreak(),
    paragraph("METHOD SELECTION AND WORK PLAN", "Kicker"),
    paragraph('<a name="algorithms"/>3. Chosen learning algorithms', "TitlePage"),
    paragraph("<b>TD3.</b> Twin Delayed Deep Deterministic Policy Gradient maps the 24 observations "
              "directly to seven continuous joint increments. It learns off-policy from replay "
              "and explores with Gaussian action noise during training. It uses the lower of two "
              "target critic estimates, smooths target actions with clipped noise, and updates "
              "the actor less often than the critics. These choices address value overestimation "
              "and unstable actor updates, both relevant when small persistent errors in seven "
              "joint commands can accumulate across a tracking episode."),
    paragraph("<b>DDPG.</b> Deep Deterministic Policy Gradient also maps the observation directly "
              "to seven continuous increments and learns off-policy from replay with Gaussian "
              "exploration. A single critic estimates the discounted return, and the actor "
              "updates through that critic using the deterministic policy gradient. The direct "
              "continuous output avoids discretizing the seven-dimensional action space and gives "
              "a comparison against TD3's twin critics, target smoothing, and delayed actor updates."),
    paragraph("Both methods use the same task, reward, training seed (2029), budget "
              "(300,000 environment steps each), and two 128-unit ReLU hidden layers per "
              "actor and critic. Inverse kinematics is reserved for the separate baseline."),
    paragraph('<a name="work-plan"/>4. Work breakdown through Progress 2', "Section"),
    table_title(3),
    table([
        ["Owner", "Progress 1 contribution", "Progress 2 deliverable"],
        ["Yousef Mohamed gharib<br/>23P0159", "Robot model, end-effector frame and forward kinematics",
         "Evidence for at least 20 valid, collision-free resets"],
        ["Basmala Helmy Lotfy Mohamed<br/>23P0359", "Observations and target/reset formulation",
         "Reset implementation and workspace checks"],
        ["Yousef Ahmed Elbaz<br/>23P0032", "Actions, constraints and termination design",
         "Step implementation, increment clipping and violation tests"],
        ["Mostafa Elmoriah<br/>23p0036", "Reward and success criteria",
         "Plots of reward and termination on two hand-built action sequences"],
        ["Aya allah muhamed<br/>2200627", "TD3/DDPG rationale and report integration",
         "30-case random-policy baseline with success rate and episode returns"],
    ], [138, 165, 195]),
]


def main():
    report = SimpleDocTemplate(str(ROOT / "Progress_1_Franka_Panda.pdf"), pagesize=A4,
                               leftMargin=PAGE_MARGIN, rightMargin=PAGE_MARGIN, topMargin=44,
                               bottomMargin=59, title="Progress 1 | Franka Panda Moving-Target Tracking")
    report.build(story, onFirstPage=footer, onLaterPages=footer)


if __name__ == "__main__":
    main()
