#import "paper.typ": *
#import "@preview/timeliney:0.1.0"

#let todo(body, inline: false, big_text: 40pt, small_text: 15pt, gap: 2mm) = []

#show: paper.with(
    font: "Palatino",
    fontsize: 10pt,
    maketitle: true,
    title: [Modern FFI alternatives for high-performance scientific computing in hybrid language workflows],
    // subtitle: "",
    authors: (
        (
            name: "Isabella Basso do Amaral",
            affiliation: "",
            email: "isabellabdoamaral@usp.br",
        ),
        (
            name: "Renato Cordeiro Ferreira",
            affiliation: [
                Mathematics and Statistics Institute (IME) \
                University of São Paulo
            ],
            email: "renatocf@ime.usp",
        ),
        (
            name: "Advisor: Alfredo Goldman Vel Lejbman",
            affiliation: [
                Mathematics and Statistics Institute (IME) \
                University of São Paulo
            ],
            email: "gold@ime.usp",
        ),
    ),
    date: datetime.today().display(),
    abstract: [
        Computer software has become an invaluable tool in our times, advancing the frontiers of what is deemed
        possible on every field, and that includes research.
        One of the most common ways to enable contemporary workloads relies on a hybrid language approach, where the
        end-user usually operates on a high-level language, such as Python, while lowering the implementation of
        critical paths to a systems programming language, which can be compiled and optimized for the target hardware.
        This can be a very daunting task for inexperienced developers, and is quite often prone to severe errors, possibly
        compromising the validity of the results, or even the safety of the system.
        In this research project, we aim to explore alternatives that can make the process less error-prone, and
        guidelines to ensure robustness and reproducibility -- a pillar of the modern scientific method.
        We begin by reviewing recent literature that has tackled similar issues.
        Then, we present a case study of a modern numerical algorithm #todo("TBD", inline: true) comparing
        Python-hybrid implementations in terms of complexity, performance, and maintainability.
    ],
    keywords: [
        Hybrid language workflows, FFI, Zig, Rust, Python, NumPy, benchmarking, scientific computing, numerical
    methods
    ],
    acknowledgments: "This paper is a work in progress. Please do not cite without permission.",
    bibliography: bibliography("refs.bib", title: "References"),
    // draft: false,
)

#set par(
  justify: true,
  leading: 0.65em,
  first-line-indent: 15pt,
  linebreaks: "optimized",
)

#show link: set text(fill: blue)
#show ref: set text(fill: blue)
#show cite: set text(fill: blue)

// #set text(spacing: 50%)

// #todo_outline

= Introduction

The role computers have acquired in our times is undeniable: from taking us to the moon, to providing optimized routes
for delivery; it has become a staple to modern human endeavors.
In order to make real progress in any field, it is necessary to have the right tools at hand, and that includes software.
Software is built on top of layers of abstraction, each one providing a higher-level interface to the developer.
Generally speaking, this does not come without costs.
It can be empirically shown that some of the so-called _zero-cost abstractions_ are not free, as they can add overhead
due to indirections.
Thus we start our discussion from the ground up, with the hardware.

== Hardware

Turing machines are the theoretical model of computation, and have been used to prove the limits of what can be
computed in a finite, or reasonable, amount of time.
The main incarnation of the Turing machine is the von Neumann architecture, which is the basis of most modern
computers @tanenbaum1997operating.

=== Von Neumann architecture

The von Neumann architecture is composed of @wiki:vonneumann:
- processing unit, which executes arithmetic instructions using registers (memory slots)
- control unit, which maintains the state of the processing unit
- memory, which stores data and instructions
- input/output, which connects the computer to the outside world
- external mass storage#footnote[
    Persistent (external mass) storage, such as hard drives or solid-state disks, is orders of magnitude slower than
    main memory, and is capable of storing data even when the computer is turned off.
    For our purposes, we only consider the main memory, which is volatile, and is used to store data that is being used by
    the system.
]

#figure(
  image("img/von-neumann-machine-diagram.png", width: 80%),
  caption: [
    A von Neumann machine diagram. Source: Wikipedia.
  ],
) <fig:von-neumann>

=== Modern systems

In modern systems, the processing unit is coupled with the control unit, in what is commonly known as the CPU, or
_Central Processing Unit_.
The CPU has become hugely complex to enable speed-ups, being usually composed of several compute units, known as
_cores_, which can act independently.
As there is no single way to encode instructions, manufacturers have settled on common sets of instructions, known as
_Instruction Set Architecture_ (ISA).
The way those instructions are then executed is up to the manufacturer, and can vary greatly between different
implementations of the same ISA.
In general, the "control" unit is responsible for fetching the instructions from memory, decoding them
and scheduling execution on a processing unit.
This control unit is usually implemented with a sequencer circuit tied to a read-only memory (ROM) in the case of
modern _AMD64_ ISA implementations.
In those implementations, after the instructions are fetched they are then sent for a queue to be matched to micro-ops
(or hardware primitives) using _microcode_ stored in the decoder ROM @chen2014security.
Each micro-op corresponds to processor primitives that can be scheduled for execution on a processing unit.#footnote[
    This can be contrasted with _firmware_, which is code made for another processor, and is usually stored in
    rewritable memory.
    Firmware is needed to initialize and control hardware devices, like RAM controllers, or the Motherboard BIOS.
    This code can be written in C, but it is out of the scope of this work.
]
There are also optimizations such as pipelining and _out-of-order execution_, where the processor groups micro-ops
that can be executed in parallel, or reorders them to maximize throughput @hennessy2011computer.

The processor, however, is not the main bottleneck in most systems.
The computer's main memory, called RAM or _Random Access Memory_, can be three orders of magnitude slower than the CPU,
not only due to its slower clock speeds, but simply being at a couple of centimeters away of the processor already
increases latency significantly.
While some manufacturers have tried addressing the physical distance, the issue is still so pertinent that it is common
to make use of _cache_ memory, which is not only physically closer to the CPU, but also optimized for speed.
The main issue with cache is that it can be very expensive, so it is usually small.
Cache has become so important that multi-core architectures will usually have a hierarchy of caches, with the L1 cache
being core-specific, and subsequent levels being shared among cores.
To address the issue further, specially in the case of vector calculations, manufacturers have also introduced SIMD (Single Instruction Multiple Data)
which enables $1/2^n$ instructions to be executed in parallel, where $n$ is the number of bits in the vector, thus
reducing the overhead of communicating that many instructions.

#figure(
  image("img/memory-performance-gap.png", width: 80%),
  caption: [
    Difference in performance of processor and memory regarding the time difference for subsequent memory accesses in
  the processor versus the latency of DRAM access.
  Source: @hennessy2011computer.
  ],
) <fig:memory-compute-gap>

#figure(
  image("img/memory-hierarchy.png", width: 80%),
  caption: [
    Memory hierarchy of a modern processor, showing the different levels of cache and their relation to the processor.
  Source: @hennessy2011computer.
  ],
) <fig:memory-hierarchy>

== Operating Systems

Since operating system became very popular in the 90s, when computers where becoming commonplace, and
the web emerged as a new medium, it is common to associate computers with their operating systems, making the case that
they were a single whole, which is the reality for consumers.
Historically, operating systems have been developed as a means of virtualizing physical resources, such as memory and
compute, while also ensuring efficient operation of the hardware.
This could be used for _time-sharing_ systems, where many users could connect to the same computer and run their
applications concurrently, without interfering with each other.
#cite(<arpaci2018operating>, form: "prose") describes three main aspects of an operating system:
- Virtualization

  The OS must provide interfaces for interacting with different hardware components, such as memory, storage,
  network cards, and peripherals.
  It also has to schedule execution of programs, deciding what to run next.

- Concurrency

  The OS has to provide concurrency primitives, such as mutexes and semaphores, to allow programs to make use of
  multi-core systems.
  It also has to enable threading and processes, however some operating systems provide different abstractions.

- Persistence

  The OS has to provide a way to store data, and to retrieve it.
  This can be done through filesystems, which are usually implemented as a tree of directories, with files at the leaves.
  The OS also has to provide a way to interact with the filesystem, such as reading and writing files and
  directories, and managing permissions.

Currently, there are few operating systems that are widely used, and most of them are based on the Unix operating system,
which makes use of a kernel to manage resources, and a shell to interact with the user.
The kernel is the main subject matter of operating systems, as it has direct access to the hardware, and is responsible
for executing programs.
There are, however, hybrid approaches, such as microkernels, which provides lower-level interfaces for user-space
services to implement, relying on small programs to perform basic system tasks @tanenbaum1997operating.#footnote([
    While it may seem unintuitive that the kernel should not be responsible for scheduling,
    #cite(<swift2010individual>, form: "prose") highlights the main advantages of such decoupling.
])

Note that kernel-space and user-space are mostly divided by the instructions they can execute on CPU.
If a program tries to execute an instruction that is not allowed, the kernel will raise an exception, and the program
will be killed.
The program must use the kernel interface to be able to ask for the physical resource, and can be denied depending on
the running user's privileges.

We can already notice that the OS is very concerned with security, which comes at a big penalty for performance.
For example, some recent hardware vulnerabilities have been patched by operating systems, such as Spectre and Meltdown,
both related to out-of-order code execution.
Performance issues with operating systems can also be traced to legacy interfaces to interact with hardware devices.
In the case of filesystems and network cards, the overhead imposed by kernel interfaces can be up to 30% @zhang2019m.
This can be mitigated with library operating systems, which bypass the kernel for specific tasks @zhang2021demikernel.
It is however, not in the scope of this work.

=== User-space dependencies

While most of what we discuss on this paper is related to end-user software libraries, it is important to note that the
operating system is not only composed of kernel and shell on modern systems.
There are many tools that aid in making an interactive experience, such as init systems, display managers, window
managers, file managers and also many different libraries that are used by developers to make those tools, and which
can be shared (dynamically linked) or statically linked (copied).
All of those compete for CPU time, and even if not relevant to our analysis, they can be a source of performance
issues, or just noise in the measurements.
There are entire teams dedicated to understanding the impact of those services and tools in high-performance settings,
and we take much inspiration from them in our analysis too.

== State of user-space software development

With user-space software we refer to the software that we, as end-users, interact with.
Most of this software is written in high-level languages, not only because they are less performance sensitive, but
oftentimes because they target other software in which they will be run, e.g. a web browser or an isolated environment
such as a container.#footnote[
    A container is a Linux-specific feature that enables applications to run sandboxed but use the same kernel as the
    host machine. It has become the most common way to deploy web applications, usually through Kubernetes or some
    other orchestration tool that enables horizontal scaling on commodity hardware.
]
Most networked services have been design to scale horizontally, whereby the same application is run on multiple
machines that are connected through a network, and can be added or removed as needed.
This makes it easier for developers to maintain large applications, as they can be broken down into smaller parts that
can each be scaled horizontally, in what is known as service-oriented architecture (SoA).
SoA is highly encouraged in object-oriented programming, a mainstream paradigm promoted by influential authors and
major companies, which developed many of the tools to build and manage microservices.
This application oriented design is known for hiding details in favor of interfaces, and where most of the performance
issues arise.
It has become common in the industry to ignore the underlying layers of abstraction, and to focus on the end-user
experience at the cost of several additional dependencies that snowball into performance issues.
While it may seem like a good trade-off, it is not always the case, as oftentimes there is compounding additional cost
to address the issue later.

The SoA approach comes in direct contrast to the lesser known data-oriented architecture (DoA), which we discuss in
detail in the following section.
It is important to note that no approach is a silver bullet, however data-oriented designs (DoD) strive to stay away
from complexity while having proven their effectiveness#footnote[
    Especially in the games industry, where performance is paramount, and the software must run on a wide range of
    devices, from consoles to high-end PCs.
], which can be very beneficial to modern machine-learning deployments, as well as scientific-computing as a whole,
having the added advantage that its core tenets can be stated as guidelines for engineers and researchers working in
those applications @cabrera2023real.

Contemporary science's reliance on software is a relatively new phenomenon.
As such, research software is commonly not held at standards as high as more traditional research methods
@sufi2014software.
It is often developed by researchers inexperienced with real world development practices and, long-term sustainability
is compromised @carver2022survey.

One particular development strategy that appeals to modern scientific standards is that of open source, in which the
code is available to users.
Notably, as open-source software is auditable, it becomes easier to verify reproducibility @barba2022defining.
This also allows for early collaboration between researchers and developers, which can lead to better software design
and performance @wilson2014best.

Building on the practice of open source we also have _free software_ (commonly denoted by FLOSS or FOSS): a development
ideology centered on volunteer work and donations, and that is permissively (_copyleft_) licensed.
There is emerging work on the role of FLOSS in science, such as #cite(<fortunato2021case>, form: "prose"), and some initiatives which praise a
similar approach @katz2018community, @barker2022introducing.
We believe that the future of scientific computing lies in the hands of open-source communities that adopt
data-oriented design principles, and that are able to leverage the latest hardware advancements.

In a field such as machine learning, it is common practice to implement and prototype algorithms in high-level
languages such as Python, due to their ease of use, powerful features, and large ecosystem.
Python is usually run by an interpreter, called CPython, which is written in C, and is responsible for translating it
into machine code.
An interpreter is a program that reads the source code of another program, translates it into bytecode, that is then
interpreted by a virtual machine, which simulates a computer that understands that binary stream (as opposed to the
actual host machine assembly, e.g. x86_64).
Compare this with a compiler, which directly translates the source code into an executable binary.
Python can also be compiled, at the cost of some flexibility, but it is also not as fast as systems programming
languages.

It is not uncommon, however, to find that the performance of the code is not up to par with the requirements of running
it for production, and it may be necessary to rewrite the application.
A complete rewrite in a compiled language with manual memory management can be very time-consuming and error-prone.
The most common alternative is to use libraries that provide bindings to compiled code, such as NumPy and Scikit-learn.
Those bindings are called _foreign function interfaces_ (FFI), and are used to call functions from one language in
another, however most commonly they are used to call C functions.#footnote[
    Even though we will be exploring alternatives to C, it is important to note that all languages use the C binary
    calling convention to address foreign functions, even if they have a different ABI.
]
We will now introduce some of the systems programming language alternatives we picked for analyzing in this research
project.

=== Systems programming languages

C is the main example of a systems programming language.
It has been successfully used to write such applications since its inception, as it was designed by Denis Ritchie to
write the Unix operating system.
Other languages are called systems programming languages because they are capable of delivering similar results to C,
or because they could be used to eventually replace C, to write a kernel for example.
The C language has become known for the wide range of vulnerabilities that can be exploited through _Undefined
Behavior_ (UB).
There have been many attempts at language paradigms or compiler technology to provide an easy way to make safe code that
is fast, and we will explore some of them.
While old-standing competitors such as C++ have tried to address some issues with C, they have also become very
complex, with their own set of pitfalls.
Others, like Java, have tried to address the issue of memory management by providing a garbage collector, which tracks
live objects by means of reference counting, and frees the memory when it is no longer needed.
This adds overhead to the program, as the garbage collector must run periodically, and can be a source of performance
issues, as the cost of garbage collection is not always predictable.#footnote[
    A commonly known issue with garbage collectors is the _stop-the-world_ problem, where the program must halt
  execution in order to perform garbage collection.
]

A modern contender for systems programming is Rust, which promises on being a safe and performant alternative to C and
C++.
The Rust programming language has invested heavily in its type system, which can prevent many common programming errors
by providing restrictive interfaces to the developer.
Traditionally, an interface is a software contract that specifies some application boundary, usually in the form of
function signatures -- the inputs and outputs of a (named) function.
In Rust, those interfaces are called `trait`s, which have an added semantic meaning of capabilities.
A common example is serialization, whereby one converts the representation of an object.
A Rust type that implements the `Serialize` trait can be converted to a JSON string, for example.
These constraints are enforced by the compiler, and allow Rust to resolve symbols more efficiently than C++, being
object-oriented, where it is common to have dynamic dispatch.#footnote[
    Rust also supports dynamic dispatch through `dyn`, but heavily discourages its use.
]
The main feature of Rust is, however, the borrow checker -- this is a static analysis tool that builds on top of the
type system, analyzing the lifetime of references to objects -- which can prevent many common programming errors, such
as _use-after-free_ and _double-free_, freeing Rust code of major sources of undefined behavior.
Prior to modern Rust, it was common to need explicit lifetimes in variables, but since that has become better
integrated through compiler inference, the language has gained wide adoption for its advanced high-level features,
usually called _zero-cost abstractions_.

Zig is another language that has gained some traction in the systems programming community.
Through the use of `comptime` blocks, developers can achieve clean and readable code generation.
Contrast it with the Rust alternatives of `macro_rules!` (which defines its own syntax) or AST-parsing macro functions
which require in-depth knowledge of compiler internals.
Zig also aims to be closer to the C language, promising on easy interoperability, and providing many ways to interface
with C libraries, which are still very common in the systems programming community.
The main selling point of Zig has been its simplicity, inspiretou by Go -- a very simple interpreted language that has
become quite popular for web development as it provides an easy way to write concurrent code, making it very
maintainable and performant.
While Zig still does not have concurrency primitives on par with Golang, another selling point is the ease of using
allocators.
When managing memory, allocators define policies to how it should be done, potentially reducing fragmentation and other
latency issues related to acquiring and releasing resources from the Operating System.
Traditionally, C and C++ have used the `malloc` and `free` functions, which are very simple, but can be a major source
of issues, as the developer must remember to free their memory appropriately, and only once.
Zig provides many different allocators that can be used, and also allows defining custom allocators, which are the only
way to allocate memory in the language.

= Background

== First term <sec:methodology:1st-term>

In October 2022 I have attended #link("https://indico.freedesktop.org/event/2/page/11-overview")[X.Org Developers
  Conference 2022] in order to present another project I have developed in
#link("https://summerofcode.withgoogle.com/programs/2022/projects/6AoBcunH")[Google Summer of Code
2022].
While it was unrelated, I got to meet many people from the open-source graphics community, and learn much about the
development of state of the art open source graphics APIs.

In the MAC0414 course, I have learned many things about the theory behind compilers, mainly through
@sipser1996introduction, which has helped me understand many ideas behind the compilation process.

Then, in the MAC0344 course I have learned about the main aspects guiding performance in modern hardware, and also
about some of their most common optimizations.

== Second term <sec:methodology:2nd-term>

I have learned about the main aspects of operating systems in the MAC5753 course, including various scheduling
algorithms, details about memory management, as well as the main aspects of file systems design.
This knowledge has already helped me break down multiple applications and systems I have encountered.
This course was also very code-intensive, which has helped me improve my C programming skills. As part of the courses'
evaluation, I have presented the #link("https://github.com/contiki-ng/contiki-ng")[Contiki-NG] operating system for
_Internet of Things_ (IoT) applications.

In the MAC5742 course, I have learned about the main aspects of parallel programming, and studied code profiling and
benchmarking.
I have also made a group presentation about federated learning, which is a distributed machine learning technique.

Finally, I presented an extended abstract of my previous work at the 2023
#link("https://sites.google.com/view/erad-sp2023/home")[ERAD-SP] conference.

== Third term <sec:methodology:3rd-term>

Both the MAC5716 and MAC5856 courses were focused on software development, and have helped me both to strengthen my
engineering skills, and to learn about the intricacies of open source software development.

=== MAC5716 - Extreme Programming Laboratory

On this course, I learned about applying Agile methods to software development by contributing to SuperLesson, a lecture
transcription CLI tool.
Unlike most other projects in the course, our team already had, as a starting point, simple scripts that the client had
started developing by himself.
The scripts were a series of six steps, processing a video lecture and the professor's presentation slides, then
producing a PDF file and the lecture transcription.
The client then used to annotate each slide manually with the relative transcription, before using it for his studies.

To tackle this problem, we started by refactoring the code, so that we would understand every intricacy of the process,
while also enabling us to add new features more easily, and convert the software into a CLI tool.
We believe this choice was essential for making the software more maintainable, and helped us advance faster.
After that, we started working on features that the client requested, to improve on the readability of the final output,
and automate the process of annotating the slides.
We have also added simple documentation, and linting tools to the project.
Apart from new features, we have also shortened processing time in many steps.
First, we made use of GPUs to generate the transcription from the lecture audio, which was the most time-consuming step,
cutting its runtime by a factor of 20x.
We were also able to improve both performance and accuracy of word splitting on slide transitions by tracking
auto-generated punctuation.
As a final improvement, we parallelized API calls to OpenAI's ChatGPT, which was the second most time-consuming step,
cutting its runtime by the number of slides in the presentation.

Apart from developing software, we gathered every week to discuss our progress, and also with the client, on a separate
occasion, for planning meetings.
Our progress was tracked mainly through high-level tasks on a Kanban board, using GitHub Projects.
This choice was made in favor of responsiveness and flexibility, as more detailed tracking would take too much time.
We mainly worked through pair programming and pull requests during the course, but we also stopped reviewing pull
requests to facilitate fast progress before delivery, with minor consequences on stability, as each change was tested
by both developers.
Our team worked on the project from september to december 2023.

=== MAC5856 - Open Source Software Development Laboratory

On this course, I learned about the various intricacies that are present on FOSS communities, and I have also
contributed to a distributed version control system (DVCS) called #link("https://github.com/martinvonz/jj")[Jujutsu (jj)].
Jj is a DVCS written in Rust, which aims to be a faster and more secure alternative to Git, and is currently still in
its beta stage.
The project was created by Martin von Zweigbergk and attempts to solve many problems that Git and other DVCSs have,
mainly focusing on easy-of-use and performance.

During the course, my pair and I had to make presentations about code style, free software groups on the Southern
Hemisphere, and the software project itself.
Preparing and presenting the presentations helped us understand the topics more deeply, especially with respect to the
software project, as we had to look up many sources to motivate its creation, and also to understand how it differed
from alternatives.
This also allowed me to look more deeply into software design, and explore how time affect it.

= Literature Review

@tab:reviewed-papers summarizes the main papers that have been reviewed in this work.
Most modern authors do not spend much time discussing implementation details, with @rotter2022nbody being an
exceptional example in many aspects.

#figure(
    caption: [Research papers reviewed in this work.],
    placement: auto,
    table(
        align: center + horizon,
        columns: (auto, auto, auto, auto),
        stroke: (top: 0.5pt, bottom: 1pt, left: 0pt, right: 0pt),
        // column-gutter: 1em,
        // column-gutter: (_, y) => if calc.odd(y) {0} else {1em},
        // inset: (x: 8pt, y: 4pt),
        // stroke: (x, y) => if y <= 1 { (top: 0.5pt) },
        // fill: (x, y) => if y > 0 and calc.rem(y, 2) == 0  { rgb("#efefef") },
        table.header(
            [Paper], [Benchmark methods], [OSS], [Source]
        ),
        cite(<rotter2022nbody>, form: "full"),
        [
            Execution time \
            Resident memory usage
        ],
        [Yes],
        link("https://github.com/MarkCLewis/MultiLanguageKDTree")[github.com/MarkCLewis/MultiLanguageKDTree],
        cite(<lin2016gc>, form: "full"),
        [
            Microbenchmarks \
            Parallel performance scaling \
            Domain-specific benchmarking tool (compares time against state-of-the-art implementation)
        ],
        [ No ],
        [],
        cite(<schubert2022medoids>, form: "full"),
        [MNIST sample runtime for a few values of N with fixed parameters],
        [Yes],
        link("https://github.com/kno10/rust-kmedoids")[github.com/kno10/rust-kmedoids],
    )
) <tab:reviewed-papers>

= Proposal

One of our goals in this work is to uncover how feasible it is to work consistently in a hybrid-language workflow,
enabling high-performance Python through foreign function interfaces (FFI) to systems programming languages.
We chose to investigate the performance of modern systems programming languages, namely Rust and Zig, as alternatives
to C, in the context of high-performance scientific computing.
For this purpose, we will be comparing the Python, C, Rust, and Zig implementations of a modern numerical algorithm
that will be used in Python.
// We decided to adopt the groundwork laid by @beyer2019benchexec in benchmarking our software, as it provides a reliable
// way to ensure reproducibility.

In order to compare Rust and Zig implementations to C, we hope to divide our analysis into three main aspects:
- Performance

    _How fast the code runs, and how much memory does it use?_ <goal:perf>

- Complexity

    _How easy is it to understand and maintain the code?_ <goal:complex>

- Maintainability

    _How easy is it to extend and modify the code, in relation to its application?_ <goal:maintain>

As a motivating example for our work, we will be looking at a toy implementation of statistics functions across our
languages of interest, with listings provided on @app:ffi-impl.
In that example, we can see that the Rust implementation is very similar to the Python implementation, but can be
faster than NumPy even if it is not loading the data with helper functions.
For our first analysis, we will be using the Python implementation as a baseline, benchmarked using `timeit`
with randomly generated data from 1000000 payment samples from 100000 users.
The calculations are run 1000 times in a single Python interpreter session, for each implementation, displayed at
@tab:toy-bench.

#figure(
    caption: [Benchmark results for the toy statistics functions implementation.],
    placement: auto,
    table(
        align: center + horizon,
        columns: (auto, auto, auto, auto, auto),
        stroke: (top: 0.5pt, bottom: 1pt, left: 0pt, right: 0pt),
        // column-gutter: 1em,
        // column-gutter: (_, y) => if calc.odd(y) {0} else {1em},
        // inset: (x: 8pt, y: 4pt),
        // stroke: (x, y) => if y <= 1 { (top: 0.5pt) },
        // fill: (x, y) => if y > 0 and calc.rem(y, 2) == 0  { rgb("#efefef") },
        table.header(
            table.cell(rowspan: 2,
                [Implementation]),
            table.cell(rowspan: 2,
                [LoC]),
            table.cell(colspan: 3,
                [avg timings (s)]),
            [avg ages], [avg payments], [stddev],
        ),
        link(<code:metrics_py>)[ Python ], [ 23 ],
        [ 0.1907 ], [ 1.9303 ], [ 39.7549 ],
        link(<code:numpy_py>)[ NumPy ], [ 13 ],
        [ 0.0371 ], [ 0.1154 ], [ 1.1720 ],
        link(<code:metrics_c>)[ C ], [ 138#footnote[
            The C implementation was written by the author, without any prior experience dealing with the Python
            extension API.
            It is still being reviewed by the author, and is expected to be improved.
        ]],
        [ 0.1933 ], [ 1.9290 ], [ 1.9450 ],
        link(<code:pyo3_sample_rs>)[ Rust ], [ 40 ],
        [ 0.0042 ], [ 0.0362 ], [ 0.5567 ],
        link(<code:metrics_zig>)[ Zig ], [ 110#footnote[
            This implementation also made use of C headers directly, making it as complex as the C
            implementation.
        ] ],
        [ 0.2566 ], [ 2.6005 ], [ 2.6351 ],
    )
) <tab:toy-bench>

#todo("talk about legacy interfaces, refs", inline: true)
#todo("discuss UB in implementations", inline: true)

We also point the reader to take a look at the Rust implementation in particular @code:pyo3_sample_rs, as it the
fastest, while also being very similar to the pure Python version @code:metrics_py with a minor discrepancy in LoC (_lines of code_).

We present a timeline of the project in @tab:timeline, starting with the relevant studies the primary author began in 2022.

// We usually measure compute performance by means of _floating point operations per second_
// _FLOPS_, as it conveys the notion of the average computation one would usually
// perform#footnote[
//     FLOPS were once very straightforward to measure, but as @dolbeau2018theoretical notes,
//     hardware complexity requires a variety of benchmarks to arrive at a more accurate measure of
//     actual performance.
// ].

#figure(
    caption: [Timeline of the project.],
    placement: auto,
    timeliney.timeline(
        show-grid: true,
        {
            import timeliney: *

            headerline(group(([*2022*], 1)), group(([*2023*], 1)), group(([*2024*], 5)), group(([*2025*], 5)))
            headerline(
                group("year"),
                group("year"),
                group("...", "Sep", "Oct", "Nov", "Dec"),
                group("Jan", "Feb", "Mar", "Apr", "May"),
            )

            taskgroup(title: [*Research*], {
                task("Theme research", (0, 5), style: (stroke: 2pt + gray))
                task("Undergrad lectures", (0, 2), style: (stroke: 2pt + gray))
                // task("", (4, ), style: (stroke: 2pt + gray))
                task("Literature research", (0.8, 5.5), style: (stroke: 2pt + gray))
                task("Benchmark techniques", (0.5, 8), style: (stroke: 2pt + gray))
                task("FFI", (2.5, 9), style: (stroke: 2pt + gray))
                task("Rust", (0.6, 7), style: (stroke: 2pt + gray))
                task("Zig", (1.5, 8), style: (stroke: 2pt + gray))
                task("Allocators", (1.9, 7), style: (stroke: 2pt + gray))
            })

            taskgroup(title: [*Development*], {
                task("Toy benchmark examples", (4.5, 6.5), style: (stroke: 2pt + gray))
                task("Onboard in the Scikit-learn project", (4, 7), style: (stroke: 2pt + gray))
                task("Rust implementation", (7, 8), style: (stroke: 2pt + gray))
                task("C implementation", (7.5, 10), style: (stroke: 2pt + gray))
                task("Zig implementation", (8, 11), style: (stroke: 2pt + gray))
                task("Benchmark", (10.5, 12), style: (stroke: 2pt + gray))
            })

            milestone(
                at: 1.8,
                style: (stroke: (dash: "dashed")),
                align(center, [
                    *Contributed to Rust projects*\
                    Oct 2023
                ])
            )

            milestone(
                at: 2.5,
                style: (stroke: (dash: "dashed")),
                align(center, [
                    *Discovered data-oriented design principles*\
                    Aug 2024
                ])
            )
        }
    )
) <tab:timeline>

#colbreak()

// Appendices

#counter(heading).update(0)
#show: set heading(numbering: "A.", supplement: [Appendix])
#show figure: set block(breakable: true)
// #show: set page(height: auto)

= FFI implementation reference <app:ffi-impl>


We have the following Python code to calculate statistics on a list of user data.
Note that we prefer to use a single class with lists in order to pack our data as efficiently as possible, and we make
use of #link("https://docs.python.org/3/library/typing.html#typing.NamedTuple")[`typing.NamedTuple`] as a
representative performant modern Python feature.

#figure(
    caption: [Pure Python implementation of the statistics functions.],
    placement: auto,
    [
```py
import math
import typing as t


class UserData(t.NamedTuple):
    ages: list[int]
    payments: list[int]

    def average_age(self):
        total_age = sum(self.ages)
        count = len(self.ages)
        return total_age / count

    def average_payment_amount(self):
        total_payment_cents = sum(self.payments)
        count = len(self.payments)
        return 0.01 * total_payment_cents / count

    # Compute the standard deviation of payment amounts
    # Variance[X] = E[X^2] - E[X]^2
    def std_dev_payment_amount(self):
        sum_square, total_sum = 0.0, 0.0
        for payment_cents in self.payments:
            payment = payment_cents * 0.01
            sum_square += payment**2
            total_sum += payment
        count = len(self.payments)
        avg_square = sum_square / count
        avg = total_sum / count
        return math.sqrt(avg_square - avg**2)
```
    ]
) <code:metrics_py>

The NumPy implementation is as follows:

#figure(
    caption: [(Python with) NumPy implementation of the statistics functions.],
    placement: auto,
    [
```py
import typing as t

import numpy as np
import numpy.typing as npt


class UserData(t.NamedTuple):
    ages: list[int]
    payments: list[int]

    def average_age(self):
        total_age = sum(self.ages)
        count = len(self.ages)
        return total_age / count

    def average_payment_amount(self):
        total_payment_cents = sum(self.payments)
        count = len(self.payments)
        return 0.01 * total_payment_cents / count

    # Compute the standard deviation of payment amounts
    # Variance[X] = E[X^2] - E[X]^2
    def std_dev_payment_amount(self):
        sum_square, total_sum = 0.0, 0.0
        for payment_cents in self.payments:
            payment = payment_cents * 0.01
            sum_square += payment**2
            total_sum += payment
        count = len(self.payments)
        avg_square = sum_square / count
        avg = total_sum / count
        return math.sqrt(avg_square - avg**2)
```
    ]
) <code:numpy_py>

While using Rust with PyO3, we have the following implementation:

#figure(
    caption: [Rust PyO3 implementation of the statistics functions.],
    placement: auto,
    [
```rust
use pyo3::prelude::*;

#[pymodule]
fn metrics_rs(m: &Bound<'_, PyModule>) -> PyResult<()> {
    m.add_class::<UserData>()
}

#[pyclass]
struct UserData {
    ages: Vec<u8>,
    payments: Vec<u32>,
}

#[pymethods]
impl UserData {
    #[new]
    fn new(ages: Vec<u8>, payments: Vec<u32>) -> Self {
        UserData { ages, payments }
    }

    /// Compute the average age
    fn average_age(&self) -> f64 {
        let sum: u64 = self.ages.iter().map(|&age| age as u64).sum();
        let count = self.ages.len() as f64;
        sum as f64 / count
    }

    /// Compute the average payment amount
    fn average_payment_amount(&self) -> f64 {
        let sum: u64 = self.payments.iter().map(|&p| p as u64).sum();
        let count = self.payments.len() as f64;
        (sum as f64 * 0.01) / count
    }

    /// Compute the standard deviation of payment amounts
    fn std_dev_payment_amount(&self) -> f64 {
        let mut sum_square = 0.0;
        let mut sum = 0.0;

        for &p in &self.payments {
            let x = p as f64 * 0.01;
            sum_square += x * x;
            sum += x;
        }

        let count = self.payments.len() as f64;
        let avg_square = sum_square / count;
        let avg = sum / count;

        (avg_square - avg * avg).sqrt()
    }
}
```
    ]
) <code:pyo3_sample_rs>

Due to time and resource constraints, we were still unable to determine enough API details through the Python external
API to match Rust performance with a pure C, or a Zig implementation.

```C
#define PY_SSIZE_T_CLEAN
#include <Python.h>
#include <math.h>
#include <stdlib.h>

typedef struct {
    PyObject_HEAD PyObject *ages;
    PyObject *payments;
} UserData;

static void UserData_dealloc(UserData *self);
static int UserData_init(UserData *self, PyObject *args, PyObject *kwds);
static PyObject *UserData_new(PyTypeObject *type, PyObject *args,
                              PyObject *kwds);

static PyObject *UserData_average_age(UserData *self) {
    if (!PyList_Check(self->ages)) {
        return NULL;
    }

    Py_ssize_t len = PyList_Size(self->ages);
    if (len == 0) {
        return NULL;
    }

    double sum = 0.0;
    for (Py_ssize_t i = 0; i < len; i++) {
        PyObject *item = PyList_GetItem(self->ages, i);
        if (!PyLong_Check(item)) {
            return NULL;
        }
        sum += PyLong_AsLong(item);
    }

    return PyFloat_FromDouble(sum / len);
}

static PyObject *UserData_average_payment_amount(UserData *self) {
    if (!PyList_Check(self->payments)) {
        return NULL;
    }

    Py_ssize_t len = PyList_Size(self->payments);
    if (len == 0) {
        return NULL;
    }

    double sum = 0.0;
    for (Py_ssize_t i = 0; i < len; i++) {
        PyObject *item = PyList_GetItem(self->payments, i);
        if (!PyLong_Check(item)) {
            return NULL;
        }
        sum += PyLong_AsLong(item);
    }

    return PyFloat_FromDouble((sum * 0.01) / len);
}

static PyObject *UserData_std_dev_payment_amount(UserData *self) {
    if (!PyList_Check(self->payments)) {
        return NULL;
    }

    Py_ssize_t len = PyList_Size(self->payments);
    if (len == 0) {
        return NULL;
    }

    double sum_square = 0.0;
    double sum = 0.0;

    for (Py_ssize_t i = 0; i < len; i++) {
        PyObject *item = PyList_GetItem(self->payments, i);
        if (!PyLong_Check(item)) {
            return NULL;
        }
        double payment = PyLong_AsLong(item) * 0.01;
        sum_square += payment * payment;
        sum += payment;
    }

    double avg_square = sum_square / len;
    double avg = sum / len;

    return PyFloat_FromDouble(sqrt(avg_square - avg * avg));
}

static PyMethodDef UserData_methods[] = {
    {"average_age", (PyCFunction)UserData_average_age, METH_NOARGS,
     "Compute average age"},
    {"average_payment_amount", (PyCFunction)UserData_average_payment_amount,
     METH_NOARGS, "Compute average payment amount"},
    {"std_dev_payment_amount", (PyCFunction)UserData_std_dev_payment_amount,
     METH_NOARGS, "Compute standard deviation of payment amounts"},
    {NULL} // Sentinel
};

static PyTypeObject UserDataType = {
    PyVarObject_HEAD_INIT(NULL, 0).tp_name = "metrics.UserData",
    .tp_doc = "UserData class",
    .tp_basicsize = sizeof(UserData),
    .tp_flags = Py_TPFLAGS_DEFAULT | Py_TPFLAGS_BASETYPE,
    .tp_new = UserData_new,
    .tp_init = (initproc)UserData_init,
    .tp_dealloc = (destructor)UserData_dealloc,
    .tp_methods = UserData_methods,
};

static PyObject *UserData_new(PyTypeObject *type, PyObject *args,
                              PyObject *kwds) {
    UserData *self = (UserData *)type->tp_alloc(type, 0);
    if (self != NULL) {
        self->ages = PyList_New(0);
        self->payments = PyList_New(0);
        if (self->ages == NULL || self->payments == NULL) {
            Py_XDECREF(self->ages);
            Py_XDECREF(self->payments);
            Py_TYPE(self)->tp_free((PyObject *)self);
            return NULL;
        }
    }
    return (PyObject *)self;
}
```

#figure(
    caption: [C Python extension implementation of the statistics functions.],
    placement: auto,
    [
```C
static int UserData_init(UserData *self, PyObject *args, PyObject *kwds) {
    PyObject *ages = NULL, *payments = NULL;

    if (!PyArg_ParseTuple(args, "OO", &ages, &payments)) {
        return -1;
    }

    if (!PyList_Check(ages) || !PyList_Check(payments)) {
        return -1;
    }

    Py_INCREF(ages);
    Py_INCREF(payments);
    Py_XDECREF(self->ages);
    Py_XDECREF(self->payments);
    self->ages = ages;
    self->payments = payments;

    return 0;
}

static void UserData_dealloc(UserData *self) {
    Py_XDECREF(self->ages);
    Py_XDECREF(self->payments);
    Py_TYPE(self)->tp_free((PyObject *)self);
}

static PyModuleDef metricsmodule = {
    PyModuleDef_HEAD_INIT,
    .m_name = "metrics_c",
    .m_doc = "Metrics module",
    .m_size = -1,
};

PyMODINIT_FUNC PyInit_metrics_c(void) {
    PyObject *m;
    m = PyModule_Create(&metricsmodule);
    PyModule_AddType(m, &UserDataType);
    return m;
}
```
]) <code:metrics_c>

```zig
const std = @import("std");

const py = @cImport({
    @cDefine("Py_LIMITED_API", "3");
    @cDefine("PY_SSIZE_T_CLEAN", {});
    @cInclude("Python.h");
});

pub export fn PyInit_metrics_zig() ?*py.PyObject {
    return py.PyModule_Create(&ModuleDef);
}

var ModuleDef = py.PyModuleDef{
    .m_base = .{
        .ob_base = .{
            .ob_type = null,
        },
        .m_init = null,
        .m_index = 0,
        .m_copy = null,
    },
    .m_name = "metrics_zig",
    .m_doc = "Metrics module implemented in Zig.",
    .m_size = -1,
    .m_methods = methods[0..],
    .m_slots = null,
    .m_traverse = null,
    .m_clear = null,
    .m_free = null,
};

var methods = [_]py.PyMethodDef{
    .{
        .ml_name = "average_age",
        .ml_meth = averageAgeCallback,
        .ml_flags = py.METH_VARARGS,
        .ml_doc = "Calculate the average age.",
    },
    .{
        .ml_name = "average_payment_amount",
        .ml_meth = averagePaymentAmountCallback,
        .ml_flags = py.METH_VARARGS,
        .ml_doc = "Calculate the average payment amount.",
    },
    .{
        .ml_name = "std_dev_payment_amount",
        .ml_meth = stdDevPaymentAmountCallback,
        .ml_flags = py.METH_VARARGS,
        .ml_doc = "Calculate the standard deviation of payment amounts.",
    },
};

fn averageAgeCallback(self: ?*py.PyObject, args: ?*py.PyObject) callconv(.C) ?*py.PyObject {
    _ = self;
    if (py.PyTuple_Size(args) != 1) return null;

    const pylist = py.PyTuple_GetItem(args, 0);
    if (pylist == null or py.PyList_Check(pylist) == 0) return null;

    const list_len = py.PyList_Size(pylist);
    if (list_len < 0) return null;

    var sum: f64 = 0;
    var i: isize = 0;
    while (i < @as(isize, @intCast(list_len))) : (i += 1) {
        const item = py.PyList_GetItem(pylist, i);
        if (item == null or py.PyLong_Check(item) == 0) return null;

        const age = py.PyLong_AsLong(item);
        if (age < 0) return null;
        sum += @floatFromInt(age);
    }

    const avg = sum / @as(f64, @floatFromInt(list_len));
    return py.PyFloat_FromDouble(avg);
}

fn averagePaymentAmountCallback(self: ?*py.PyObject, args: ?*py.PyObject) callconv(.C) ?*py.PyObject {
    _ = self;
    if (py.PyTuple_Size(args) != 1) return null;

    const pylist = py.PyTuple_GetItem(args, 0);
    if (pylist == null or py.PyList_Check(pylist) == 0) return null;

    const list_len = py.PyList_Size(pylist);
    if (list_len < 0) return null;

    var sum: f64 = 0;
    var i: isize = 0;
    while (i < @as(isize, @intCast(list_len))) : (i += 1) {
        const item = py.PyList_GetItem(pylist, i);
        if (item == null or py.PyLong_Check(item) == 0) return null;

        const payment = py.PyLong_AsLong(item);
        if (payment < 0) return null;
        sum += @floatFromInt(payment);
    }

    const avg = 0.01 * sum / @as(f64, @floatFromInt(list_len));
    return py.PyFloat_FromDouble(avg);
}
```

#figure(
    caption: [Zig Python extension implementation of the statistics functions.],
    placement: auto,
    [
```zig
fn stdDevPaymentAmountCallback(self: ?*py.PyObject, args: ?*py.PyObject) callconv(.C) ?*py.PyObject {
    _ = self;
    if (py.PyTuple_Size(args) != 1) return null;

    const pylist = py.PyTuple_GetItem(args, 0);
    if (pylist == null or py.PyList_Check(pylist) == 0) return null;

    const list_len = py.PyList_Size(pylist);
    if (list_len < 0) return null;

    var sum_square: f64 = 0.0;
    var sum: f64 = 0.0;
    var i: isize = 0;
    while (i < @as(isize, @intCast(list_len))) : (i += 1) {
        const item = py.PyList_GetItem(pylist, i);
        if (item == null or py.PyLong_Check(item) == 0) return null;

        const payment = py.PyLong_AsLong(item);
        if (payment < 0) return null;
        const payment_float = @as(f64, @floatFromInt(payment)) * 0.01;
        sum_square += payment_float * payment_float;
        sum += payment_float;
    }

    const count: f64 = @floatFromInt(list_len);
    const avg_square = sum_square / count;
    const avg = sum / count;
    const std_dev = std.math.sqrt(avg_square - avg * avg);
    return py.PyFloat_FromDouble(std_dev);
}
```
]) <code:metrics_zig>
